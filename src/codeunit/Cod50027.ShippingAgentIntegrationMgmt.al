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
        JsonValue: JsonValue;
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
        JsonValue.SetValueToNull();
        JSonPickUpAddressAttribute.Add('BuildingNumber', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('BuildingName', JsonValue.AsToken());

        JSonPickUpAddressAttribute.Add('Floor', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('Apartment', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('POBox', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('Description', JsonValue.AsToken());

        //PickupContact
        PickupContactAttribute.Add('Department', 'Test Department');
        PickupContactAttribute.Add('PersonName', 'Test Person Name');
        PickupContactAttribute.Add('Title', JsonValue.AsToken());
        PickupContactAttribute.Add('CompanyName', 'Test Person/Company Name');
        PickupContactAttribute.Add('PhoneNumber1', '97148707700');
        PickupContactAttribute.Add('PhoneNumber1Ext', JsonValue.AsToken());
        PickupContactAttribute.Add('PhoneNumber2', JsonValue.AsToken());
        PickupContactAttribute.Add('PhoneNumber2Ext', JsonValue.AsToken());
        PickupContactAttribute.Add('FaxNumber', JsonValue.AsToken());
        PickupContactAttribute.Add('CellPhone', '97148707700');
        PickupContactAttribute.Add('EmailAddress', 'pickupemail@test.com');
        PickupContactAttribute.Add('Type', JsonValue.AsToken());

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
        MergeAddressAndContact.Add('Vehicle', JsonValue.AsToken());
        MergeAddressAndContact.Add('Shipments', JsonValue.AsToken());

        //PickupItems as an array
        PickupItemAttribute.Add('ProductGroup', 'DOM');
        PickupItemAttribute.Add('ProductType', 'ONP');
        PickupItemAttribute.Add('NumberOfShipments', 1);
        PickupItemAttribute.Add('PackageType', 'item');
        PickupItemAttribute.Add('Payment', 'P');
        PickupItemAttribute.Add('ShipmentWeight', JsonValue.AsToken());
        PickupItemAttribute.Add('ShipmentVolume', JsonValue.AsToken());
        PickupItemAttribute.Add('NumberOfPieces', 1);
        PickupItemAttribute.Add('CashAmount', JsonValue.AsToken());
        PickupItemAttribute.Add('ExtraCharges', JsonValue.AsToken());
        PickupItemAttribute.Add('ShipmentDimensions', JsonValue.AsToken());
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

        MergeAddressAndContact.Add('Branch', JsonValue.AsToken());
        MergeAddressAndContact.Add('RouteCode', JsonValue.AsToken());
        MergeAddressAndContact.Add('Dispatcher', 0);

        //MergeAddressAndContact -> Pickup
        JsonPickUp.Add('Pickup', MergeAddressAndContact);
        JsonPickUp.Add('LabelInfo', JsonValue.AsToken());

        //ClientInfo
        ClientInfoAttributes.Add('UserName', 'testingapi@aramex.com');
        ClientInfoAttributes.Add('Password', 'R123456789$r');
        ClientInfoAttributes.Add('Version', 'v1.0');
        ClientInfoAttributes.Add('AccountNumber', '45796');
        ClientInfoAttributes.Add('AccountPin', '116216');
        ClientInfoAttributes.Add('AccountEntity', 'DXB');
        ClientInfoAttributes.Add('AccountCountryCode', 'AE');
        ClientInfoAttributes.Add('Source', 24);
        ClientInfoAttributes.Add('PreferredLanguageCode', JsonValue.AsToken());

        //ClientInfoAttributes - > JsonPickUp
        JsonPickUp.Add('ClientInfo', ClientInfoAttributes);
        JsonPickUp.Add('Transaction', JsonValue.AsToken());

        Message(Format(JsonPickUp));
    end;
}
