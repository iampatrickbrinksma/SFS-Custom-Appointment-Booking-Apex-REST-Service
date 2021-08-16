/**
 * Purpose: 
 * IMPORTANT: This code is not intended to be deployed to a Salesforce production environment.
 * It is intended as an example of how to book an appointment using Apex REST services
 * 
 * Author: Patrick Brinksma (Salesforce)
 * Class: Apex REST service to retrieve available time slots. 
 * This class performs a callout to create the Work Order and Service Appointment 
 * so that is performed in a separate transaction to allow Field Service to perform
 * a callout for travel time calculations.
 */
@RestResource(urlMapping='/getSlots/*')
global without sharing class RESTGetSlots {

    @HttpPost
    global static void doPost() {
        try {
            // Measure performance
            Long start = System.now().getTime();
            // REST Context
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            // Return object
            RESTObjects.getSlotResults getSlotsResult = new RESTObjects.getSlotResults();
            // Get Request Body and convert to object
            RESTObjects.jobDetails jobDetails = (RESTObjects.jobDetails)JSON.deserialize(req.requestBody.toString(), RESTObjects.jobDetails.class);      
            // Measure performance of inner REST API call
            Long startInnerREST = System.now().getTime();
            // Prepare inner REST API callout to create WO + SA
            Http http = new Http();
            HttpRequest request = new HttpRequest();        
            request.setMethod('POST');
            request.setEndpoint('callout:SalesforceToSameOrg/services/apexrest/createJobDetails');
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            // Set ST explicitely for now, as we can't wait for geocoding to finish and ST to be assigned via Polygons!
            ServiceTerritory st = RESTFieldServiceParams.getServiceTerritory();
            // Add ST Id to details and set the Body of the inner REST API Call
            jobDetails.stId = st.Id;
            request.setBody(JSON.serialize(jobDetails));
            // Perform REST API call
            HttpResponse response = http.send(request);
            // Parse results
            if (response.getStatusCode() == 200){
                RESTObjects.createSA createSA = (RESTObjects.createSA)JSON.deserialize(response.getBody(), RESTObjects.createSA.class);
                // Capture performance of job details creation
                getSlotsResult.createSAtimeInMs = createSA.timeInMs;
                // Measure performance of inner REST API call
                getSlotsResult.innerRESTtimeInMs = (System.now().getTime() - startInnerREST);
                // Retrieve details to perform getSlots
                System.TimeZone tz = TimeZone.getTimeZone(st.OperatingHours.TimeZone);
                Id ohId = RESTFieldServiceParams.getOperatingHoursId();
                Id schedPolId = RESTFieldServiceParams.getSchedulingPolicyId();
                // Get time slots using FSL Managed Package method
                List<FSL.AppointmentBookingSlot> timeSlots = FSL.AppointmentBookingService.GetSlots(createSA.sa.Id, schedPolId, ohId, tz, false);
                // Process results
                getSlotsResult.result = 'Success';
                getSlotsResult.timezone = tz.toString();
                getSlotsResult.timezoneid = tz.getID();
                getSlotsResult.slots = new List<RESTObjects.slot>();
                for (FSL.AppointmentBookingSlot timeSlot : timeSlots){
                    RESTObjects.slot slot = new RESTObjects.slot();
                    slot.grade = timeSlot.Grade;
                    slot.start = timeSlot.Interval.start;
                    slot.finish = timeSlot.Interval.finish;
                    slot.startandfinish = timeSlot.Interval.toString();
                    getSlotsResult.slots.add(slot);
                }
                // Measure performance
                getSlotsResult.getslotstimeInMs = (System.now().getTime() - start);
                // Remove the WO + SA
                delete new WorkOrder(Id = createSA.sa.ParentRecordId);
                // Set response
                res.responseBody = Blob.valueOf(JSON.serialize(getSlotsResult));
            } else {
                // Return body to the caller to handle the exception
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = response.getBodyAsBlob();
            }
            // Return void
            return;
        } catch (Exception e){
            // If there is a JSON exception, the payload is not correct
            // and this exception needs to be raised!
            if (Type.forName(e.getTypeName()) == System.JSONException.class){
                throw new RESTException('REST_JSON_PAYLOAD_ERROR\n\nStacktrace: ' + e.getStackTraceString());
            } else {
                throw(e);
            }
        }
    }
}