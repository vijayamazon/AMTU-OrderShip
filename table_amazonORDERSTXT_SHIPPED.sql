/*
** amazonORDERSTXT_SHIPPED
** auth: JFM
** desc: Table create script for output table
**
** Version History
**
** V1.0 8/29/2014 -- Created
**
*/
CREATE TABLE amazonORDERSTXT_SHIPPED(
	order_id varchar(50) NULL,
	order_item_id varchar(150) NULL,
	purchase_date varchar(25) NULL,
	sku varchar(512) NULL,
	quantity_purchased varchar(5) NULL,
	quantity_shipped int null,
	date_shipped varchar(100),
	carrier_code varchar(100),
	carrier_name varchar(200),
	trackingNumber varchar(100),
	statusCode int,
	dateProcessed datetime)