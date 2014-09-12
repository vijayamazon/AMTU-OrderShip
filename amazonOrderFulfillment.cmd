cd c:\amazoninventory
del order.xml
sqlcmd -i createAmazon_OrderFulfillment.sql -o order.xml -W -h-1 -S 192.0.0.100 -U username -P mypass
copy order.xml c:\amazondata\production\outgoing\amaInventory.xml