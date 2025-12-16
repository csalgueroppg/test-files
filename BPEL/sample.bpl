<?xml version="1.0" encoding="UTF-8"?>
<process
    name="OrderProcessingProcess"
    targetNamespace="http://example.com/bpel/order"
    xmlns="http://docs.oasis-open.org/wsbpel/2.0/process/executable"
    xmlns:tns="http://example.com/bpel/order"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:ord="http://example.com/schema/order"
    suppressJoinFailure="yes">

    <!-- ================================================= -->
    <!-- Partner Links                                     -->
    <!-- ================================================= -->
    <partnerLinks>
        <partnerLink name="client"
                     partnerLinkType="tns:OrderPLT"
                     myRole="OrderProcessor"/>

        <partnerLink name="inventoryService"
                     partnerLinkType="tns:InventoryPLT"
                     partnerRole="InventoryService"/>

        <partnerLink name="paymentService"
                     partnerLinkType="tns:PaymentPLT"
                     partnerRole="PaymentService"/>

        <partnerLink name="shippingService"
                     partnerLinkType="tns:ShippingPLT"
                     partnerRole="ShippingService"/>
    </partnerLinks>

    <!-- ================================================= -->
    <!-- Variables                                         -->
    <!-- ================================================= -->
    <variables>
        <variable name="orderRequest" messageType="ord:OrderRequestMessage"/>
        <variable name="orderResponse" messageType="ord:OrderResponseMessage"/>

        <variable name="inventoryResponse" messageType="ord:InventoryResponseMessage"/>
        <variable name="paymentResponse" messageType="ord:PaymentResponseMessage"/>
        <variable name="shippingResponse" messageType="ord:ShippingResponseMessage"/>

        <variable name="faultInfo" messageType="ord:FaultMessage"/>
    </variables>

    <!-- ================================================= -->
    <!-- Main Process Logic                                -->
    <!-- ================================================= -->
    <sequence name="MainSequence">

        <!-- Receive Order -->
        <receive name="ReceiveOrder"
                 partnerLink="client"
                 operation="submitOrder"
                 portType="ord:OrderPortType"
                 variable="orderRequest"
                 createInstance="yes"/>

        <!-- Validate Order -->
        <if name="ValidateOrder">
            <condition>
                $orderRequest.payload/ord:order/ord:amount > 0
            </condition>

            <sequence name="ValidOrder">

                <!-- Parallel Processing -->
                <flow name="ParallelProcessing">

                    <!-- Inventory Reservation Scope -->
                    <scope name="InventoryScope">
                        <compensationHandler>
                            <invoke name="CancelInventory"
                                    partnerLink="inventoryService"
                                    operation="releaseInventory"
                                    portType="ord:InventoryPortType"
                                    inputVariable="orderRequest"/>
                        </compensationHandler>

                        <invoke name="ReserveInventory"
                                partnerLink="inventoryService"
                                operation="reserveInventory"
                                portType="ord:InventoryPortType"
                                inputVariable="orderRequest"
                                outputVariable="inventoryResponse"/>
                    </scope>

                    <!-- Payment Processing Scope -->
                    <scope name="PaymentScope">
                        <compensationHandler>
                            <invoke name="RefundPayment"
                                    partnerLink="paymentService"
                                    operation="refund"
                                    portType="ord:PaymentPortType"
                                    inputVariable="orderRequest"/>
                        </compensationHandler>

                        <invoke name="ChargePayment"
                                partnerLink="paymentService"
                                operation="charge"
                                portType="ord:PaymentPortType"
                                inputVariable="orderRequest"
                                outputVariable="paymentResponse"/>
                    </scope>

                </flow>

                <!-- Shipping -->
                <invoke name="ShipOrder"
                        partnerLink="shippingService"
                        operation="ship"
                        portType="ord:ShippingPortType"
                        inputVariable="orderRequest"
                        outputVariable="shippingResponse"/>

                <!-- Prepare Response -->
                <assign name="PrepareResponse">
                    <copy>
                        <from expression="'SUCCESS'"/>
                        <to variable="orderResponse"
                            part="status"/>
                    </copy>
                </assign>

                <!-- Reply to Client -->
                <reply name="ReplySuccess"
                       partnerLink="client"
                       operation="submitOrder"
                       portType="ord:OrderPortType"
                       variable="orderResponse"/>

            </sequence>

            <!-- Invalid Order -->
            <else>
                <assign name="InvalidOrderResponse">
                    <copy>
                        <from expression="'INVALID_ORDER'"/>
                        <to variable="orderResponse"
                            part="status"/>
                    </copy>
                </assign>

                <reply name="ReplyInvalid"
                       partnerLink="client"
                       operation="submitOrder"
                       portType="ord:OrderPortType"
                       variable="orderResponse"/>
            </else>
        </if>

    </sequence>

    <!-- ================================================= -->
    <!-- Fault Handling                                    -->
    <!-- ================================================= -->
    <faultHandlers>
        <catchAll>
            <sequence name="FaultSequence">

                <!-- Trigger Compensation -->
                <compensate/>

                <!-- Prepare Fault Response -->
                <assign name="PrepareFault">
                    <copy>
                        <from expression="'PROCESSING_ERROR'"/>
                        <to variable="orderResponse"
                            part="status"/>
                    </copy>
                </assign>

                <reply name="ReplyFault"
                       partnerLink="client"
                       operation="submitOrder"
                       portType="ord:OrderPortType"
                       variable="orderResponse"/>
            </sequence>
        </catchAll>
    </faultHandlers>

</process>
