/*
** createAmazon_OrderFulfillment
** Auth: JFM
** Desc: Script to generate XML file for Amazon Orders
**
** Revision History
**
**	V1.0   08/20/2014 -- Created
*/

/*	Set count off for output */
	set nocount on;
/*
** Declare local variables for cursor
*/

	declare @v_order_id varchar(50);
	declare @v_order_item_id varchar(150);
	declare @v_purchase_date varchar(25);
	declare @v_sku varchar(512);
	declare @v_quantity_purchased varchar(5);
	declare @v_quantity_shipped int;
	declare @v_date_shipped varchar(100);
	declare @v_carrier_code varchar(100);
	declare @v_carrier_name varchar(200);
	declare @v_trackingNumber varchar(100);
	declare @v_statusCode int;
	declare @v_dateProcessed datetime;
	declare amazonOrderID cursor local static for
		select distinct order_id, date_shipped, carrier_code, carrier_name, trackingnumber from amazonORDERSTXT_SHIPPED;
	
	/*
	** Error handling and tex string variables
	*/
	declare @v_tmpstr varchar(2000);
	declare @v_messageNumber int;
	declare @v_recordCount int;
	declare @ErrorMessage NVARCHAR(4000);
    declare @ErrorSeverity INT;
    declare @ErrorState INT;
/*
**	Stubs.	In the sample data, the quantity_shipped, date_shipped, carrier_code,
**			carrier_name, trackingNumber are blank/0/null.  They would need to be
**			filled in with values from your ERP/Order system.   We'll
**			simulate this with some stub code here
*/
	
	/* Set quantity shipped = quantity ordered */
	begin try
		update amazonORDERSTXT_SHIPPED set quantity_shipped = quantity_purchased;
	end try
	begin catch
    	SELECT @ErrorMessage = 'ERR Setting Quantity_shipped:'+ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();
    	RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
	end catch;
	
	/* Set date_shipped to today's date in Amazon's required format */
	begin try
		update amazonORDERSTXT_SHIPPED set date_shipped = REPLACE(CONVERT(VARCHAR(10), GETDATE(), 111), '/', '-');
	end try
	begin catch
    	SELECT @ErrorMessage = 'ERR Setting date_shipped:'+ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();
    	RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
	end catch;
	
	/* Shipping
	** Amazon requires the use of either the carrier_code or the carrier_name.  We've
	** built this using carrier_code, as Amazon supports almost every carrier that you
	** can think of.  Carrier_code values:
	** [Blue Package, USPS, UPS, UPSMI, FedEx, DHL, 
	** DHL Global Mail, Fastway, UPS Mail Innovations, Lasership, Royal Mail, FedEx 
	** SmartPost, OSM, OnTrac, Streamlite, Newgistics, Canada Post, City Link, GLS, 
	** GO!, Hermes Logistik Gruppe, Parcelforce, TNT, Target, SagawaExpress, NipponExpress, 
	** YamatoTransport, Other]  
	**
	** If you use "Other", then you must fill in a value for
	** the carrier_name -- this is not covered in this code
	*/
	begin try
		update amazonorderstxt_shipped set carrier_code = 'UPS',
			trackingnumber = '1Z9999999999999999';
	end try
	begin catch
    	SELECT @ErrorMessage = 'ERR Setting carrier_code and trackingnumber:'+ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();
    	RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
	end catch;

	/* end of stub code */
	
/* Here is where it gets interesting, start of the code that produces the output  */

	/* 
	** Declare an in-memory table structure hold the output.   ROWDATA is the key, but
	** we declare a rowid identity column so that we output the records in the exact
	** order that we put them into the table
	*/	
    declare @ng_amazonOrders TABLE (rowid int identity, rowdata varchar(1000) )
  
  	/*
  	** Add Amazon headers to in memory table
  	*/
  	begin try
		insert into @ng_amazonOrders (rowdata)
			values ('<?xml version="1.0" encoding="UTF-8"?>');
		insert into @ng_amazonOrders (rowdata)
			values ('<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">');
		insert into @ng_amazonOrders (rowdata)
			values ('<Header>');
		/*
		** This is the row that you will have to change -- replacing AAAAAAAAAAAAA with YOUR merchant ID
		*/
		insert into @ng_amazonOrders (rowdata)
			values ('<DocumentVersion>1.01</DocumentVersion><MerchantIdentifier>AAAAAAAAAAAAA</MerchantIdentifier></Header>');
		insert into @ng_amazonOrders (rowdata)
			values ('<MessageType>OrderFulfillment</MessageType>');
		end try
	begin catch
    	SELECT @ErrorMessage = 'ERR inserting header rows into XML table:'+ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();
    	RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
	end catch;
	
	/*
	** As the amazonORDERSTXT_SHIPPED table is non-normalized (following Amazon's design), we need
	** two cursors, one to the get the unique order, shipping and tracking information and one
	** to loop through the items on the order
	*/
	
	/* 
	** Open the first cursor,  which gets us the distinct:
	** order_id, date_shipped, carrier_code, carrier_name, trackingnumber
	*/
	begin try
		OPEN amazonOrderID;
		
		FETCH NEXT FROM amazonOrderID INTO @v_order_id, @v_date_shipped, @v_carrier_code, @v_carrier_name, 
			@v_trackingnumber;
	end try
	begin catch
    	SELECT @ErrorMessage = 'ERR opening amazonOrderID cursor and fetching:'+ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();
    	RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
	end catch;
	
	/*
	** Amazon requires each message in an XML document to have a unique number, we use a
	** simple counter for this
	*/
	set @v_messageNumber = 1;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		begin try
			/*
			** Insert the first message (converting the message number from int to string)
			*/
			select @v_tmpstr = '<Message><MessageID>'+cast(@v_messageNumber as varchar)+ '</MessageID><OrderFulfillment>';
			insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
			/*
			** Insert the order header information (order id, shipdate)
			*/
			select @v_tmpstr = '<AmazonOrderID>'+@v_order_id+ '</AmazonOrderID>';
			insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
			/*
			** Shipping date already formatted in the proper string format above
			*/
			select @v_tmpstr = '<FulfillmentDate>'+rtrim(@v_date_shipped)+'</FulfillmentDate>';
			insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
			/*
			** Shipping information
			*/
			select @v_tmpstr = '<FulfillmentData><CarrierCode>'+@v_carrier_code+'</CarrierCode>';
			insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
		
			select @v_tmpstr = '<ShipperTrackingNumber>'+@v_trackingnumber+'</ShipperTrackingNumber></FulfillmentData>';
			insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
		end try
		begin catch
			SELECT @ErrorMessage = 'ERR inserting message header data:'+ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();
			Close amazonCursor;
			Deallocate amazonCursor;
			RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
		end catch;
		
		/*
		** We have the header for the order, now we have to loop through and get
		** them items and quantities for the order
		*/
		begin try
			declare amazonOrderItems CURSOR local static for
				select order_item_id, quantity_shipped from amazonORDERSTXT_SHIPPED where order_id = @v_order_id;
			open amazonOrderItems
			FETCH NEXT FROM amazonOrderItems INTO @v_order_item_id, @v_quantity_shipped;
		end try
		begin catch
			SELECT @ErrorMessage = 'ERR opening amazonOrderItems cursor :'+ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();
			RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
		end catch;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			begin try
				/*
				** For each item, add an "Item" tag, item id and quantity
				*/
				select @v_tmpstr = '<Item>';
				insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);

				select @v_tmpstr = '<AmazonOrderItemCode>'+@v_order_item_id+'</AmazonOrderItemCode>';
				insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
			
				select @v_tmpstr = '<Quantity>'+cast(@v_quantity_shipped as varchar)+'</Quantity></Item>';
				insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
				end try
			begin catch
				SELECT @ErrorMessage = 'ERR inserting order item records :'+ERROR_MESSAGE(),
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE();
				RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
			end catch;
			
   			FETCH NEXT FROM amazonOrderItems INTO @v_order_item_id, @v_quantity_shipped;
   			
   		END
   		begin try
   			/*
   			** Close the inner cursor
   			*/
			Close amazonOrderItems;
			Deallocate amazonOrderItems;
			/*
			** Insert the closing tags for this order
			*/
			select @v_tmpstr = '</OrderFulfillment></Message>';
			insert into @ng_amazonOrders (rowdata) values (@v_tmpstr);
		end try
		begin catch
			SELECT @ErrorMessage = 'ERR closing inner cursor and writing end-of-order tags :'+ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();
			RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
		end catch;
		
		/*
		** Get next order header and update the message count
		*/
		FETCH NEXT FROM amazonOrderID INTO @v_order_id, @v_date_shipped, @v_carrier_code, @v_carrier_name, 
			@v_trackingnumber;
		set @v_messageNumber = @v_messageNumber + 1;
	END
	begin try
		Close amazonOrderID;
		Deallocate amazonOrderID;

		insert into @ng_amazonOrders (rowdata) values ('</AmazonEnvelope>');
	end try
	begin catch
		SELECT @ErrorMessage = 'ERR closing outer cursor and writing end-of-document tag :'+ERROR_MESSAGE(),
		@ErrorSeverity = ERROR_SEVERITY(),
		@ErrorState = ERROR_STATE();
		RAISERROR (@ErrorMessage,@ErrorSeverity, @ErrorState);
	end catch;
	/*
	** Return document to caller
	*/
	select rowdata from @ng_amazonOrders order by rowid asc;


