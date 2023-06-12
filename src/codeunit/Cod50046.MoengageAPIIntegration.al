codeunit 50046 "Moengage API Integration"
{
    trigger OnRun()
    var

    begin
        AzadeaSetup.get();

        if not AzadeaSetup."Send Order Status To Moengage" then
            exit;
        AzadeaSetup.TestField("Moengage API Key");
        AzadeaSetup.TestField("Moengage API URL");

        if Format(AzadeaSetup."Dont Send Events Older than") > '' then
            IgnoreOldEvents();

        OrderTrackingStatus.Reset();
        OrderTrackingStatus.SetFilter("Integrtation Status", '%1|%2', '', 'FAIL');
        if OrderTrackingStatus.FindSet() then
            repeat
                if (IsStatusEnabled) then
                    OrderTrackingStatusToMoengaeAPI();
            until OrderTrackingStatus.Next() = 0;
        MoveSuccessStatusToHistoryTable();
    end;


    var
        AzadeaSetup: Record "Azadea Setup";
        OrderTrackingStatus: Record "Order Tracking Status";
        OrderTrackingStatusMaster: Record "Order Tracking Status Master";

    local procedure IsStatusEnabled(): Boolean
    var

    begin
        OrderTrackingStatusMaster.Reset();
        OrderTrackingStatusMaster.SetRange(code, OrderTrackingStatus.Status);
        OrderTrackingStatusMaster.SetRange("Update To Moengage", true);
        if OrderTrackingStatusMaster.FindSet() then
            exit(true)
        else
            exit(false);
    end;

    local procedure OrderTrackingStatusToMoengaeAPI()
    var
        Item: Record Item;
        JObject: JsonObject;
        JObjAction: JsonObject;
        JObjAttributes: JsonObject;
        JArrAction: JsonArray;
    begin
        //Construct Json
        JObject.Add('type', 'event');
        JObject.Add('customer_id', GetCustomerEmail(OrderTrackingStatus."Document No."));
        JObjAction.Add('action', OrderTrackingStatus.Status);
        JObjAttributes.Add('InternetOrderNo', OrderTrackingStatus."Internet Order No.");
        JObjAttributes.Add('productId', OrderTrackingStatus."Item No.");
        if Item.get(OrderTrackingStatus."Item No.") then
            item.CalcFields(item."Brand Name");
        JObjAttributes.Add('ProductBrand', Item."Brand Name");
        JObjAttributes.Add('ProductDescription', ConvertTextToUTF8(Item.Description));
        JObjAttributes.Add('Qty', Format(OrderTrackingStatus.Quantity));
        JObjAttributes.Add('TotalLineQty', Format(OrderTrackingStatus."Total Line Qty."));
        JObjAttributes.Add('TotalProcessedQty', Format(OrderTrackingStatus."Total Processed Qty."));
        JObjAttributes.Add('TotalOrderQty', Format(OrderTrackingStatus."Total Order Qty."));
        JObjAttributes.Add('TotalAggregatedQty', Format(OrderTrackingStatus."Total aggregated Qty."));
        JObjAttributes.Add('ProductPrice', Format(OrderTrackingStatus."Product Price"));
        JObjAttributes.Add('OrderAmount', Format(OrderTrackingStatus."Order Amount"));
        JObjAttributes.Add('OrderDiscountAmount', Format(OrderTrackingStatus."Order Discount Amount"));
        JObjAttributes.Add('PaymentMethod', Format(OrderTrackingStatus."Payment Method"));
        JObjAttributes.Add('ShippingAddress', ConvertTextToUTF8(GetCustomerAddress(OrderTrackingStatus."Document No.", false, true)));
        JObjAttributes.Add('BillingAddress', ConvertTextToUTF8(GetCustomerAddress(OrderTrackingStatus."Document No.", true, false)));
        JObjAttributes.Add('DeliveryStatus', Format(OrderTrackingStatus."Delivery Status"));
        JObjAttributes.Add('AzadeaDeliveryStatus', Format(OrderTrackingStatus."Azadea Status"));
        JObjAttributes.Add('DeliveryTrackingLink', Format(OrderTrackingStatus."Package Tracking URL"));
        JObjAttributes.Add(OrderTrackingStatus.Status + '_Date', Format(DT2Date(OrderTrackingStatus.SystemCreatedAt)));
        JObjAttributes.Add('BulkyItem', IsBulkyItem(Item));
        JObjAttributes.Add('SplitShipment', IsSplitshipment());
        JObjAction.Add('attributes', JObjAttributes.AsToken());
        JArrAction.Add(JObjAction);
        JObject.Add('actions', JArrAction);
        SendData(JObject); //Send Json to API
    end;

    procedure ConvertTextToUTF8(pText: Text) rUTF8Text: Text
    var
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
    begin
        Clear(TempBlob);
        TempBlob.CreateOutStream(OutStr, TextEncoding::Windows);
        TempBlob.CreateInStream(InStr);
        OutStr.WriteText(pText);
        InStr.ReadText(rUTF8Text);
        exit(rUTF8Text)
    end;

    local procedure GetCustomerEmail(OrderNo: code[20]): Text
    var
        SalInvHdr: Record "Sales Invoice Header";
        SalHdr: Record "Sales Header";
        InternetOrderHeader: Record "Internet Order Header";

    begin
        if SalHdr.get(SalHdr."Document Type"::Order, OrderNo) then
            exit(SalHdr."Bill-to E-Mail");
        if IsRetrunOrder() then
            OrderNo := OrderTrackingStatus."Internet Order No.";

        if OrderTrackingStatus."Document Type" <> OrderTrackingStatus."Document Type"::"Sales Order" then
            OrderNo := OrderTrackingStatus."Internet Order No.";

        SalInvHdr.SetRange("Order No.", OrderNo);
        if SalInvHdr.FindFirst() then
            exit(SalInvHdr."Bill-to E-Mail");

        //If order cancelled No order and Invoice will be exsist, without Customer email id event cant be sent.
        if IsCancelledOrder() then begin
            InternetOrderHeader.SetCurrentKey("Original Order No.");
            InternetOrderHeader.SetRange("Original Order No.", OrderNo);
            InternetOrderHeader.SetRange(Status, InternetOrderHeader.Status::Converted);
            if InternetOrderHeader.FindFirst() then
                exit(InternetOrderHeader."Bill-to E-Mail");
        end;

    end;

    local procedure GetCustomerAddress(OrderNo: code[20]; Bill: Boolean; Sell: Boolean): Text
    var
        SalInvHdr: Record "Sales Invoice Header";
        SalHdr: Record "Sales Header";
        InternetOrderHeader: Record "Internet Order Header";
    begin
        if (bill) and (SalHdr.get(SalHdr."Document Type"::Order, OrderNo)) then
            exit(SalHdr."Bill-to Address" + ',' + SalHdr."Bill-to Address 2" + ',' + SalHdr."Bill-to City" + ',' + SalHdr."Bill-to Country/Region Code");

        if (sell) and (SalHdr.get(SalHdr."Document Type"::Order, OrderNo)) then
            exit(SalHdr."Sell-to Address" + ',' + SalHdr."Sell-to Address 2" + ',' + SalHdr."Sell-to City" + ',' + SalHdr."Sell-to Country/Region Code");

        if IsRetrunOrder() then
            OrderNo := OrderTrackingStatus."Internet Order No.";

        SalInvHdr.SetRange("Order No.", OrderNo);
        if SalInvHdr.FindFirst() then begin
            if Bill then
                exit(SalInvHdr."Bill-to Address" + ',' + SalInvHdr."Bill-to Address 2" + ',' + SalInvHdr."Bill-to City" + ',' + SalInvHdr."Bill-to Country/Region Code")
            else
                if sell then
                    exit(SalInvHdr."Sell-to Address" + ',' + SalInvHdr."Sell-to Address 2" + ',' + SalInvHdr."Sell-to City" + ',' + SalInvHdr."Sell-to Country/Region Code");
        end;

        InternetOrderHeader.SetCurrentKey("Internet Order Reference");
        InternetOrderHeader.SetRange("Internet Order Reference", OrderNo);
        InternetOrderHeader.Setrange(Status, InternetOrderHeader.Status::Converted);
        if InternetOrderHeader.FindFirst() then begin
            if Bill then
                exit(InternetOrderHeader."Bill-to Address" + ',' + InternetOrderHeader."Bill-to Address 2" + ',' + InternetOrderHeader."Bill-to City" + ',' + InternetOrderHeader."Bill-to Country Code")
            else
                if sell then
                    exit(InternetOrderHeader."Sell-to Address" + ',' + InternetOrderHeader."Sell-to Address 2" + ',' + InternetOrderHeader."Sell-to City" + ',' + InternetOrderHeader."Ship-to Country Code");
        end;
    end;

    local procedure SendData(var JObject: JsonObject)
    var
        Clients: HttpClient;
        Response: HttpResponseMessage;
        RequestHeader: HttpHeaders;
        URL: Text;
        Result: text;
        Contents: HttpContent;
        RequestContents: HttpContent;
        Output: text;
        contentHeaders: HttpHeaders;
    begin

        RequestHeader := Clients.DefaultRequestHeaders;
        RequestHeader.Add('Authorization', 'Basic ' + AzadeaSetup."Moengage API Key");
        url := AzadeaSetup."Moengage API URL" + AzadeaSetup."Moengage APP ID" + '?';

        RequestContents.WriteFrom(ReadJson(JObject));
        RequestContents.GetHeaders(contentHeaders);
        contentHeaders.Clear();
        contentHeaders.Add('Content-Type', 'application/json');

        Clients.Post(url, RequestContents, Response);
        if Response.IsSuccessStatusCode then begin
            Contents := Response.Content;
            Response.Content.ReadAs(Result);
            StoreRespose(Result);
        end else
            Message('Response negative %1 %2', Response.HttpStatusCode, Response.ReasonPhrase);
        Contents.ReadAs(Output);
        //  Message(Output);
    end;

    local procedure StoreRespose(var Result: Text)
    var
        JObjectRes: JsonObject;
        JTokenRes: JsonToken;
        UpdateOrderTrackingStatus: Record "Order Tracking Status";
        ErrorResponse: text;
        JObjectResErr: JsonObject;
        JTokenResErr: JsonToken;
    begin
        UpdateOrderTrackingStatus.get(OrderTrackingStatus."Entry No.");
        JObjectRes.ReadFrom(Result);
        JObjectRes.get('status', JTokenRes);
        UpdateOrderTrackingStatus."Integrtation Status" := JTokenRes.AsValue().AsCode();
        if UpdateOrderTrackingStatus."Integrtation Status" = 'SUCCESS' then begin
            JObjectRes.get('message', JTokenRes);
            UpdateOrderTrackingStatus.Remarks := JTokenRes.AsValue().AsText();
        end;
        if UpdateOrderTrackingStatus."Integrtation Status" = 'FAIL' then begin
            JObjectRes.get('error', JTokenRes);
            JTokenRes.WriteTo(ErrorResponse);
            JObjectResErr.ReadFrom(ErrorResponse);
            JObjectResErr.get('message', JTokenResErr);
            UpdateOrderTrackingStatus.Remarks := JTokenResErr.AsValue().AsText();
        end;
        if UpdateOrderTrackingStatus.Modify(false) then
            Commit(); //To update the intergation status immediate to avoid sending duplicate status.
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
        if (AzadeaSetup."Show MoEngage Request") and ((CurrentClientType = ClientType::Web) or (CurrentClientType = ClientType::Windows)) then
            Message(Result); //Constructed Json
        exit(Result);
    end;

    local procedure MoveSuccessStatusToHistoryTable()
    var
        OrderTrackStatus: Record "Order Tracking Status";
        OrderTrackStatusHistory: Record "Order Tracking Status History";
    begin
        OrderTrackStatus.Reset();
        orderTrackStatus.SetFilter("Integrtation Status", '%1|%2', 'SUCCESS', 'MANUALIGNORE');
        if orderTrackStatus.Findset() then
            repeat
                OrderTrackStatusHistory.TransferFields(orderTrackStatus);
                OrderTrackStatusHistory."Entry No." := 0;
                if OrderTrackStatusHistory.Insert() then
                    OrderTrackStatus.Delete();
            until orderTrackStatus.Next() = 0;
    end;

    local procedure IgnoreOldEvents()
    var
        OrderTrackStatus: Record "Order Tracking Status";
        OrderTrackStatusHistory: Record "Order Tracking Status History";
        FromDate: Date;
    begin
        FromDate := CalcDate(AzadeaSetup."Dont Send Events Older than", Today);
        OrderTrackStatus.Reset();
        OrderTrackStatus.Setfilter(SystemCreatedAt, '<%1', (CreateDateTime(FromDate, 0T)));
        if orderTrackStatus.Findset() then
            OrderTrackStatus.ModifyAll("Integrtation Status", 'MANUALIGNORE');
        Commit();
    end;

    procedure ReCreateEntries(OrderTrackStatusHistory: Record "Order Tracking Status History")
    var
        OrderTrackStatus: Record "Order Tracking Status";
    begin
        OrderTrackStatus.TransferFields(OrderTrackStatusHistory);
        OrderTrackStatus."Entry No." := 0;
        OrderTrackStatus.Status := '';
        OrderTrackStatus."Integrtation Status" := '';
        OrderTrackStatus."Delivery Status" := '';
        OrderTrackStatus.Resent := true;
        OrderTrackStatus.Insert();
    end;

    local procedure IsRetrunOrder(): boolean
    var
        myInt: Integer;
    begin
        OrderTrackingStatusMaster.SetRange(Code, OrderTrackingStatus.Status);
        OrderTrackingStatusMaster.SetRange("Status Type", OrderTrackingStatusMaster."Status Type"::Returned);
        if OrderTrackingStatusMaster.FindSet() then
            exit(true);
    end;

    local procedure IsCancelledOrder(): boolean
    begin
        OrderTrackingStatusMaster.Reset();
        OrderTrackingStatusMaster.SetRange(Code, OrderTrackingStatus.Status);
        case OrderTrackingStatusMaster."Status Type" of
            OrderTrackingStatusMaster."Status Type"::"Refund Cancelled Order", OrderTrackingStatusMaster."Status Type"::"Refund Cancelled Whse Shipment",
             OrderTrackingStatusMaster."Status Type"::"Refund Customer Return":
                begin
                    exit(true);
                end;
        end;
    end;

    local procedure IsBulkyItem(var Item: Record Item): text
    var

    begin
        if Item."Special Equipment Code" <> '' then
            exit('TRUE')
        else
            exit('FALSE')

    end;

    local procedure IsSplitshipment(): text
    var

    begin
        if OrderTrackingStatus.SplitShipment then
            exit('TRUE')
        else
            exit('FALSE')

    end;

}

