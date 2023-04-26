codeunit 50027 "ShippingAgent Integration Mgmt"
{
    trigger OnRun()
    begin
        InitiateCreatePickFromAWB();
    end;

    procedure CreatePickup(Var pSalesHeader: Record "Sales Header"; var ShippingAgentServices: Record "Shipping Agent Services")
    var
        JsonPickUp: JsonObject;
        JSonPickUpAddressAttribute, PickupContactAttribute, ClientInfoAttributes : JsonObject;
        MergeAddressAndContact: JsonObject;
        PickupItemArray, ExistingShipmentsArray : JsonArray;
    begin
        SetRecords(pSalesHeader, ShippingAgentServices);
        GetCommunicationAddress(SalesHeader);

        BuildPickupAddressJson(JSonPickUpAddressAttribute);  //PickupAddress        
        BuildPickupContactJson(PickupContactAttribute);     //PickupContact  

        MergeAddressAndContactJson(MergeAddressAndContact, JSonPickUpAddressAttribute, PickupContactAttribute); //PickupAddress &PickupContact -> MergeAddressAndContact 

        BuildPickupItemsArrayJson(PickupItemArray); //PickupItems as an array        
        MergePickupItemsArrayAndMergeAddressAndContactJson(MergeAddressAndContact, PickupItemArray); //PickupItems -> MergeAddressAndContact

        BuildExistingShipmentsAttributeJson(MergeAddressAndContact, ExistingShipmentsArray); //ExistingShipments as an array
        MergeExistingShipmentsArrayJson(MergeAddressAndContact, ExistingShipmentsArray);//ExistingShipmentsArray -> MergeAddressAndContact

        MergeAddressAndContactPickupJson(JsonPickUp, MergeAddressAndContact); //MergeAddressAndContact -> Pickup        

        BuildClientInfoJson(ClientInfoAttributes);//ClientInfo
        MergeClientInfoAttributesandPickJson(JsonPickUp, ClientInfoAttributes);//ClientInfoAttributes - > JsonPickUp

        SendJsonData(JsonPickUp);
    end;

    local procedure SendJsonData(var JsonPickUp: JsonObject)
    var
        Clients: HttpClient;
        HttpReqMessage: HttpRequestMessage;
        Response: HttpResponseMessage;
        Contents: HttpContent;
        contentHeaders: HttpHeaders;
        Result: text;
    begin
        Contents.WriteFrom(ReadJson(JsonPickUp));

        Contents.GetHeaders(contentHeaders);
        contentHeaders.Clear();
        contentHeaders.Add('Content-Type', 'application/json');

        HttpReqMessage.Content := Contents;
        HttpReqMessage.SetRequestUri(ShippingAgentService."Service URL");
        HttpReqMessage.Method := 'POST';

        Clients.send(HttpReqMessage, Response);
        Response.Content.ReadAs(Result);
        StoreRespose(Result);
        Message(Result);
    end;

    local procedure ReadJson(var JObject: JsonObject): text
    var
        InStr: InStream;
        OutStr: OutStream;
        TempBlob: Codeunit "Temp Blob";
        Result: text;
    begin
        TempBlob.CreateInStream(InStr);
        TempBlob.CreateOutStream(OutStr);
        JObject.WriteTo(OutStr);
        OutStr.WriteText(Result);
        InStr.ReadText(Result);
        Message(Result); //Constructed Json
        exit(Result);
    end;

    local procedure StoreRespose(var Result: Text)
    var
        JSONManagement: Codeunit "JSON Management";
        ProcessedPickup, NotificationsJsonArray : text;
        NotificationsJMgmnt, ProcessedPickupJMgmnt : Codeunit "JSON Management";
        NotificationsJObject: JsonObject;
        ErrCode, NotificationMsg, HasErrors : text;
        i: Integer;
        ResponseID, ResponseGUID, ResponseRef1, ResponseRef2 : text;
        AirwayBill: Record "Airway Bill";
        BigText: BigText;
        AramexError: Label '%1 : %2 - %3';
        IntegrationErrorHandler: Codeunit "Integration Error Handler";
    begin
        JSONManagement.InitializeObject(Result);
        if JSONManagement.GetArrayPropertyValueAsStringByName('Notifications', NotificationsJsonArray) then begin
            NotificationsJMgmnt.InitializeCollection(NotificationsJsonArray);

            for i := 0 to NotificationsJMgmnt.GetCollectionCount() - 1 do begin
                NotificationsJMgmnt.GetObjectFromCollectionByIndex(NotificationsJsonArray, i);
                NotificationsJMgmnt.InitializeObject(NotificationsJsonArray);
                NotificationsJMgmnt.GetStringPropertyValueByName('Code', ErrCode);
                NotificationsJMgmnt.GetStringPropertyValueByName('Message', NotificationMsg);
            end;
        end;
        JSONManagement.GetArrayPropertyValueAsStringByName('HasErrors', HasErrors);

        if JSONManagement.GetArrayPropertyValueAsStringByName('ProcessedPickup', ProcessedPickup) then begin
            ProcessedPickupJMgmnt.InitializeObject(ProcessedPickup);
            ProcessedPickupJMgmnt.GetStringPropertyValueByName('ID', ResponseID);
            ProcessedPickupJMgmnt.GetStringPropertyValueByName('GUID', ResponseGUID);
            ProcessedPickupJMgmnt.GetStringPropertyValueByName('Reference1', ResponseRef1);
            ProcessedPickupJMgmnt.GetStringPropertyValueByName('Reference2', ResponseRef2);

            if ((HasErrors = 'True') and (ResponseID <> '')) or (HasErrors = 'False') then begin
                AirwayBill.SetRange("Source No.", SalesHeader."No.");
                AirwayBill.SetRange("No.", GetShipmentNoAWB());
                AirwayBill.SetFilter("Pickup ID", '');
                if AirwayBill.FindSet() then begin
                    AirwayBill."Pickup ID" := ResponseID;
                    AirwayBill."Pickup GUID" := ResponseGUID;
                    AirwayBill.Modify();
                end;
            end else
                if GuiAllowed then
                    Error(AramexError, ShippingAgent.Code, ErrCode, NotificationMsg);
            IntegrationErrorHandler.LogError('Aramex', '', '', SalesHeader."Document Type".AsInteger(), SalesHeader."No.", 0, StrSubstNo(AramexError, ShippingAgent.Code), '', 0, NotificationMsg, '');
        end;
    end;

    local procedure InitiateCreatePickFromAWB()
    var
        AirwayBill: Record "Airway Bill";
        SalesHeader: Record "Sales Header";
        ShippingAgentServices: Record "Shipping Agent Services";
    begin
        AirwayBill.SetCurrentKey("Source Type", "Source Subtype");
        AirwayBill.SetRange("Source Type", 37);
        AirwayBill.SetRange("Source Subtype", AirwayBill."Source Subtype"::"Return Order");
        AirwayBill.SetRange("Azadea Status", AirwayBill."Azadea Status"::"Order Created");
        AirwayBill.SetFilter("Pickup ID", '');
        if AirwayBill.FindSet() then
            repeat
                if SalesHeader.get(SalesHeader."Document Type"::"Return Order", AirwayBill."Source No.") then begin
                    ShippingAgentService.SetRange("Shipping Agent Code", AirwayBill."Shipping Agent");
                    ShippingAgentService.SetRange(Type, ShippingAgentService.Type::Pickup);
                    if ShippingAgentService.FindSet() then
                        CreatePickup(SalesHeader, ShippingAgentServices);
                end;
            until AirwayBill.Next() = 0;
    end;

    local procedure SetRecords(var pSalesHeader: Record "Sales Header"; var ShippingAgentServices: Record "Shipping Agent Services")
    begin
        SalesHeader := pSalesHeader;
        ShippingAgentService := ShippingAgentServices;
        ShippingAgent.Get(ShippingAgentService."Shipping Agent Code");
        CompanyInformation.Get();
    end;

    local procedure GetCommunicationAddress(Var SalesHeader: Record "Sales Header")
    var
    begin
        Clear(PickupAddress);
        PickupAddress.Insert(1, format(SalesHeader."Sell-to Address"));
        PickupAddress.Insert(2, format(SalesHeader."Sell-to Address 2"));
        PickupAddress.Insert(3, format(SalesHeader."Sell-to City"));
        PickupAddress.Insert(4, format(SalesHeader."Sell-to Country/Region Code"));
        PickupAddress.Insert(5, format(SalesHeader."Sell-to Customer Name"));
        PickupAddress.Insert(6, format(SalesHeader."Ship-to Phone No."));
        PickupAddress.Insert(7, format(SalesHeader."Ship-to Phone No."));
        PickupAddress.Insert(8, format(SalesHeader."Bill-to E-Mail"));
        PickupAddress.Insert(9, format(GetItemDesctiptions));
        PickupAddress.Insert(10, format(SalesHeader."Original Order No."));
        PickupAddress.Insert(11, format(SalesHeader."No."));
        PickupAddress.Insert(12, format(GetShipmentNoAWB()));
    end;

    local procedure GetItemDesctiptions(): text
    var
        ItemDescriptions: Text;
        InternetorderLine: Record "Internet Order Line";
    begin
        InternetorderLine.SetRange("Internet Order Reference", SalesHeader."No.");
        if InternetorderLine.FindSet() then
            repeat
                if ItemDescriptions = '' then
                    ItemDescriptions += InternetorderLine.Description
                else
                    ItemDescriptions += ',' + InternetorderLine.Description;
            until InternetorderLine.Next() = 0;
        exit(ItemDescriptions)
    end;

    local procedure GetShipmentNoAWB(): Text
    var
        AirwayBill: Record "Airway Bill";
    begin
        AirwayBill.SetRange("Source No.", SalesHeader."No.");
        if AirwayBill.FindLast() then
            exit(AirwayBill."No.")
    end;

    local procedure BuildPickupAddressJson(var JSonPickUpAddressAttribute: JsonObject)
    begin
        JSonPickUpAddressAttribute.Add('Line1', PickupAddress.Get(1));
        JSonPickUpAddressAttribute.Add('Line2', PickupAddress.Get(2));
        JSonPickUpAddressAttribute.Add('Line3', '');
        JSonPickUpAddressAttribute.Add('City', PickupAddress.Get(3));
        JSonPickUpAddressAttribute.Add('StateOrProvinceCode', PickupAddress.Get(3));
        JSonPickUpAddressAttribute.Add('PostCode', '');
        JSonPickUpAddressAttribute.Add('CountryCode', PickupAddress.Get(4));
        JSonPickUpAddressAttribute.Add('Longitude', 0);
        JSonPickUpAddressAttribute.Add('Latitude', 0);
        JsonValue.SetValueToNull();
        JSonPickUpAddressAttribute.Add('BuildingNumber', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('BuildingName', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('Floor', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('Apartment', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('POBox', JsonValue.AsToken());
        JSonPickUpAddressAttribute.Add('Description', JsonValue.AsToken());
    end;

    local procedure BuildPickupContactJson(var PickupContactAttribute: JsonObject)
    begin
        PickupContactAttribute.Add('Department', '');
        PickupContactAttribute.Add('PersonName', PickupAddress.Get(5));
        PickupContactAttribute.Add('Title', JsonValue.AsToken());
        PickupContactAttribute.Add('CompanyName', '');
        PickupContactAttribute.Add('PhoneNumber1', PickupAddress.Get(6));
        PickupContactAttribute.Add('PhoneNumber1Ext', JsonValue.AsToken());
        PickupContactAttribute.Add('PhoneNumber2', JsonValue.AsToken());
        PickupContactAttribute.Add('PhoneNumber2Ext', JsonValue.AsToken());
        PickupContactAttribute.Add('FaxNumber', JsonValue.AsToken());
        PickupContactAttribute.Add('CellPhone', PickupAddress.Get(7));
        PickupContactAttribute.Add('EmailAddress', PickupAddress.Get(8));
        PickupContactAttribute.Add('Type', JsonValue.AsToken());
    end;

    local procedure MergeAddressAndContactJson(var MergeAddressAndContact: JsonObject; var JSonPickUpAddressAttribute: JsonObject; var PickupContactAttribute: JsonObject)
    var
        DateTimeString: Label '/Date(%1)/';
        OrginalOrderNo: Label 'Orginal Order No : %1';
    begin
        MergeAddressAndContact.Add('PickupAddress', JSonPickUpAddressAttribute);
        MergeAddressAndContact.Add('PickupContact', PickupContactAttribute);
        MergeAddressAndContact.Add('PickupLocation', PickupAddress.Get(1));//Reception
        GetPickUpReadyDateTime();
        //message(Format(Format((GetUnixTimeStamp(CurrentDateTime)), 0, 1)));
        MergeAddressAndContact.Add('PickupDate', StrSubstNo(DateTimeString, Format((GetUnixTimeStamp(PickUpReadyDTTime)), 0, 1)));
        MergeAddressAndContact.Add('ReadyTime', StrSubstNo(DateTimeString, Format((GetUnixTimeStamp(PickUpReadyDTTime)), 0, 1)));
        //MergeAddressAndContact.Add('ReadyTime', '/Date(1676379600000)/');
        MergeAddressAndContact.Add('LastPickupTime', StrSubstNo(DateTimeString, Format((GetUnixTimeStamp(LastPickupClosingTime)), 0, 1)));
        MergeAddressAndContact.Add('ClosingTime', StrSubstNo(DateTimeString, Format((GetUnixTimeStamp(LastPickupClosingTime)), 0, 1)));
        MergeAddressAndContact.Add('Comments', PickupAddress.Get(9));//open ended field, pass awb and item description
        MergeAddressAndContact.Add('Reference1', StrSubstNo(OrginalOrderNo, PickupAddress.Get(10)));
        MergeAddressAndContact.Add('Reference2', PickupAddress.Get(11));
        MergeAddressAndContact.Add('Vehicle', JsonValue.AsToken());
        MergeAddressAndContact.Add('Shipments', JsonValue.AsToken());
    end;

    local procedure BuildPickupItemsArrayJson(var PickupItemArray: JsonArray)
    var
        PickupItemAttribute: JsonObject;
    begin
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
        PickupItemAttribute.Add('Comments', '');
        PickupItemArray.Add(PickupItemAttribute);
    end;

    local procedure BuildExistingShipmentsAttributeJson(var MergeAddressAndContact: JsonObject; var ExistingShipmentsArray: JsonArray)
    var
        ExistingShipmentsAttribute: JsonObject;
    begin
        //Remove after test
        AzadeaSetup.Get();
        if AzadeaSetup."Aramex Shipment No" <> '' then
            ExistingShipmentsAttribute.Add('Number', Format(AzadeaSetup."Aramex Shipment No"))
        else
            //Remove after test
            MergeAddressAndContact.Add('Number', PickupAddress.Get(12)); //ExistingShipmentsAttribute.Add('Number', '44097921744');
        ExistingShipmentsAttribute.Add('OriginEntity', Format(ShippingAgent."Account Entity"));
        ExistingShipmentsAttribute.Add('ProductGroup', 'DOM');
        ExistingShipmentsArray.Add(ExistingShipmentsAttribute);
    end;

    local procedure MergePickupItemsArrayAndMergeAddressAndContactJson(var MergeAddressAndContact: JsonObject; var PickupItemArray: JsonArray)
    begin
        MergeAddressAndContact.Add('PickupItems', PickupItemArray);
        MergeAddressAndContact.Add('Status', 'Ready');
    end;

    local procedure MergeExistingShipmentsArrayJson(var MergeAddressAndContact: JsonObject; var ExistingShipmentsArray: JsonArray)
    begin
        MergeAddressAndContact.Add('ExistingShipments', ExistingShipmentsArray);

        MergeAddressAndContact.Add('Branch', JsonValue.AsToken());
        MergeAddressAndContact.Add('RouteCode', JsonValue.AsToken());
        MergeAddressAndContact.Add('Dispatcher', 0);
    end;

    local procedure MergeAddressAndContactPickupJson(var JsonPickUp: JsonObject; var MergeAddressAndContact: JsonObject)
    begin
        JsonPickUp.Add('Pickup', MergeAddressAndContact);
        JsonPickUp.Add('LabelInfo', JsonValue.AsToken());
    end;

    local procedure BuildClientInfoJson(var ClientInfoAttributes: JsonObject)
    begin
        ClientInfoAttributes.Add('UserName', format(ShippingAgent.UserName));
        ClientInfoAttributes.Add('Password', Format(ShippingAgent.Password));
        ClientInfoAttributes.Add('Version', 'v1.0');
        ClientInfoAttributes.Add('AccountNumber', Format(ShippingAgent."Account No."));
        ClientInfoAttributes.Add('AccountPin', Format(ShippingAgent."Account Pin"));
        ClientInfoAttributes.Add('AccountEntity', Format(ShippingAgent."Account Entity"));
        ClientInfoAttributes.Add('AccountCountryCode', Format(CompanyInformation."Country/Region Code"));
        ClientInfoAttributes.Add('Source', 24);
        ClientInfoAttributes.Add('PreferredLanguageCode', JsonValue.AsToken());
    end;

    local procedure MergeClientInfoAttributesandPickJson(var JsonPickUp: JsonObject; var ClientInfoAttributes: JsonObject)
    begin
        JsonPickUp.Add('ClientInfo', ClientInfoAttributes);
        JsonPickUp.Add('Transaction', JsonValue.AsToken());
        //Message(Format(JsonPickUp));
    end;

    procedure GetPickUpReadyDateTime()
    var
        ReadyTime: Time;
        WorkingDay: Boolean;
        PickupDate: Date;
    begin
        LastPickupClosingTime := 0DT;
        PickUpReadyDTTime := 0DT;

        CompanyInformation."Base Calendar Code" := ShippingAgentService."Base Calendar Code";
        CalendarManagement.SetSource(CompanyInformation, CustomizedCalendarChange);

        ReadyTime := System.Time + 3600000;
        PickupDate := Today;

        //Remove after test
        if AzadeaSetup."Aramex Pickup Creation Time" <> 0T then
            ReadyTime := AzadeaSetup."Aramex Pickup Creation Time";
        //Remove after test

        if ReadyTime >= ShippingAgentService."Pickup End Time" then
            PickupDate += 1;

        repeat
            if not CalendarManagement.IsNonworkingDay(PickupDate, CustomizedCalendarChange) then
                WorkingDay := true
            else
                PickupDate += 1;
        until WorkingDay = true;
        // Message(Format(PickupDate));
        if PickupDate > Today then
            PickUpReadyDTTime := System.CreateDateTime(PickupDate, ShippingAgentService."Pickup Start Time");

        if (format(PickUpReadyDTTime) = '') then begin
            if (ReadyTime < ShippingAgentService."Pickup End Time") and (ReadyTime > ShippingAgentService."Pickup Start Time") then
                PickUpReadyDTTime := System.CreateDateTime(PickupDate, ReadyTime)
            else
                if ReadyTime < ShippingAgentService."Pickup Start Time" then
                    PickUpReadyDTTime := System.CreateDateTime(PickupDate, ShippingAgentService."Pickup Start Time");
        end;
        LastPickupClosingTime := System.CreateDateTime(PickupDate, ShippingAgentService."Pickup End Time");
    end;

    procedure GetUnixTimeStamp(FromDateTime: DateTime): Decimal
    var
        TypeHelper: Codeunit "Type Helper";
        OriginDateTime: DateTime;
        TimeZoneOffset: Duration;
    begin
        TypeHelper.GetUserTimezoneOffset(TimeZoneOffset);
        OriginDateTime := System.CreateDateTime(DMY2Date(1, 1, 1970), 0T);
        OriginDateTime := OriginDateTime + TimeZoneOffset;
        exit(FromDateTime - OriginDateTime);
    end;

    var
        SalesHeader: Record "Sales Header";
        ShippingAgentService: Record "Shipping Agent Services";
        ShippingAgent: Record "Shipping Agent";
        CustomizedCalendarChange: Record "Customized Calendar Change";
        CalendarManagement: Codeunit "Calendar Management";
        CompanyInformation: Record "Company Information";
        JsonValue: JsonValue;
        PickUpReadyDTTime: DateTime;
        LastPickupClosingTime: DateTime;
        PickupAddress: List of [Text];
        AzadeaSetup: Record "Azadea Setup"; //Remove after test
}
