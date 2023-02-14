codeunit 50027 "ShippingAgent Integration Mgmt"
{
    trigger OnRun()
    var

    begin
        BuildCreatePickupJson();
    end;

    local procedure BuildCreatePickupJson()
    var
        JsonPickUp: JsonObject;
        JSonPickUpAddressAttribute, PickupContactAttribute, PickupItemAttribute, ExistingShipmentsAttribute, ClientInfoAttributes : JsonObject;
        MergeAddressAndContact: JsonObject;
        PickupItemArray, ExistingShipmentsArray : JsonArray;
    begin
        //PickupAddress
        JSonPickUpAddressAttribute.Add('Line1', 'TestAddres1');
        JSonPickUpAddressAttribute.Add('Line2', 'Test Address Line 2');
        JSonPickUpAddressAttribute.Add('Line3', '');
        JSonPickUpAddressAttribute.Add('City', 'Dubai');
        JSonPickUpAddressAttribute.Add('StateOrProvinceCode', 'Dubai');
        JSonPickUpAddressAttribute.Add('PostCode', '');
        JSonPickUpAddressAttribute.Add('CountryCode', 'AE');
        JSonPickUpAddressAttribute.Add('Longitude', 0);
        JSonPickUpAddressAttribute.Add('Latitude', 0);
        JSonPickUpAddressAttribute.Add('BuildingNumber', 'null');
        JSonPickUpAddressAttribute.Add('BuildingName', 'null');
        JSonPickUpAddressAttribute.Add('Floor', 'null');
        JSonPickUpAddressAttribute.Add('Apartment', 'null');
        JSonPickUpAddressAttribute.Add('POBox', 'null');
        JSonPickUpAddressAttribute.Add('Description', 'null');

        //PickupContact
        PickupContactAttribute.Add('Department', 'Test Department');
        PickupContactAttribute.Add('PersonName', 'Test Person Name');
        PickupContactAttribute.Add('Title', 'null');
        PickupContactAttribute.Add('CompanyName', 'Test Person/Company Name');
        PickupContactAttribute.Add('PhoneNumber1', '97148707700');
        PickupContactAttribute.Add('PhoneNumber1Ext', 'null');
        PickupContactAttribute.Add('PhoneNumber2', 'null');
        PickupContactAttribute.Add('PhoneNumber2Ext', 'null');
        PickupContactAttribute.Add('FaxNumber', 'null');
        PickupContactAttribute.Add('CellPhone', '97148707700');
        PickupContactAttribute.Add('EmailAddress', 'pickupemail@test.com');
        PickupContactAttribute.Add('Type', 'null');

        //PickupAddress &PickupContact -> MergeAddressAndContact 
        MergeAddressAndContact.Add('PickupAddress', JSonPickUpAddressAttribute);
        MergeAddressAndContact.Add('PickupContact', PickupContactAttribute);

        MergeAddressAndContact.Add('PickupLocation', 'Reception');
        MergeAddressAndContact.Add('PickupDate', '/Date(1676363400000)/');
        MergeAddressAndContact.Add('ReadyTime', '/Date(1676379600000)/');
        MergeAddressAndContact.Add('LastPickupTime', '/Date(1676386800000)/');
        MergeAddressAndContact.Add('ClosingTime', '/Date(1676386800000)/');
        MergeAddressAndContact.Add('Comments', 'open ended field, pass awb and item description');
        MergeAddressAndContact.Add('Reference1', '5dff00be7ad4f30cd9c3119d');
        MergeAddressAndContact.Add('Reference2', 'test');
        MergeAddressAndContact.Add('Vehicle', 'null');
        MergeAddressAndContact.Add('Shipments', 'null');

        //PickupItems as an array
        PickupItemAttribute.Add('ProductGroup', 'DOM');
        PickupItemAttribute.Add('ProductType', 'ONP');
        PickupItemAttribute.Add('NumberOfShipments', 1);
        PickupItemAttribute.Add('PackageType', 'item');
        PickupItemAttribute.Add('Payment', 'P');
        PickupItemAttribute.Add('ShipmentWeight', 'null');
        PickupItemAttribute.Add('ShipmentVolume', 'null');
        PickupItemAttribute.Add('NumberOfPieces', 1);
        PickupItemAttribute.Add('CashAmount', 'null');
        PickupItemAttribute.Add('ExtraCharges', 'null');
        PickupItemAttribute.Add('ShipmentDimensions', 'null');
        PickupItemAttribute.Add('Comments', 'no description');
        PickupItemArray.Add(PickupItemAttribute);

        //PickupItems -> MergeAddressAndContact
        MergeAddressAndContact.Add('PickupItems', PickupItemArray);
        MergeAddressAndContact.Add('Status', 'Ready');

        //ExistingShipments as an array
        ExistingShipmentsAttribute.Add('Number', '44097921744');
        ExistingShipmentsAttribute.Add('OriginEntity', 'DXB');
        ExistingShipmentsAttribute.Add('ProductGroup', 'DOM');
        ExistingShipmentsArray.Add(ExistingShipmentsAttribute);

        //ExistingShipmentsArray -> MergeAddressAndContact
        MergeAddressAndContact.Add('ExistingShipments', ExistingShipmentsArray);

        MergeAddressAndContact.Add('Branch', 'null');
        MergeAddressAndContact.Add('RouteCode', 'null');
        MergeAddressAndContact.Add('Dispatcher', 0);

        //MergeAddressAndContact -> Pickup
        JsonPickUp.Add('Pickup', MergeAddressAndContact);
        JsonPickUp.Add('LabelInfo', 'null');

        //ClientInfo
        ClientInfoAttributes.Add('UserName', 'testingapi@aramex.com');
        ClientInfoAttributes.Add('Password', 'R123456789$r');
        ClientInfoAttributes.Add('Version', 'v1.0');
        ClientInfoAttributes.Add('AccountNumber', '45796');
        ClientInfoAttributes.Add('AccountPin', '116216');
        ClientInfoAttributes.Add('AccountEntity', 'DXB');
        ClientInfoAttributes.Add('AccountCountryCode', 'AE');
        ClientInfoAttributes.Add('Source', 24);
        ClientInfoAttributes.Add('PreferredLanguageCode', 'null');

        //ClientInfoAttributes - > JsonPickUp
        JsonPickUp.Add('ClientInfo', ClientInfoAttributes);
        JsonPickUp.Add('Transaction', 'null');

        Message(Format(JsonPickUp));
    end;
}
