/**
 * Purpose: 
 * IMPORTANT: This code is not intended to be deployed to a Salesforce production environment.
 * It is intended as an example of how to book an appointment using Apex REST services
 * 
 * Author: Patrick Brinksma (Salesforce)
 * Class: Apex REST service to create a Work Order with the provided details.
 * If an error occurs, it is thrown to the calling class for handling, no explicit try/catch.
 */
@RestResource(urlMapping='/createJobDetails/*')
global without sharing class RESTCreateJobDetails {

    @HttpPost
    global static void doPost() {
        // Measure performance
        Long start = System.now().getTime();
        // Return object
        RESTObjects.createSA createSA = new RESTObjects.createSA();
        // REST Context
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        // Get Request Body (JSON) and convert to object
        RESTObjects.jobDetails jobDetails = (RESTObjects.jobDetails)JSON.deserialize(req.requestBody.toString(), RESTObjects.jobDetails.class);
        // Retrieve the Work Type Id by the provided name
        List<WorkType> workTypes = [select Id from WorkType where Name = :jobDetails.worktype];
        // If the Work Type could not be found, raise exception
        if (workTypes.isEmpty()) {
            throw(new RESTException('REST_WORKTYPE_NOT_FOUND'));
        }
        // Get the first Id, even if there are multiple
        Id workTypeId = workTypes[0].Id;
        // Create the Work Order
        WorkOrder wo = new WorkOrder(
            Subject = jobDetails.subject, 
            Description = jobDetails.description, 
            WorkTypeId = workTypeId, 
            Street = jobDetails.street, 
            PostalCode = jobDetails.postalcode, 
            City = jobDetails.city, 
            Country = jobDetails.country,
            ServiceTerritoryId = jobDetails.stId
        );
        insert wo; 
        // Assuming Work Type has Auto Create Appointment set to true, retrieve SA
        ServiceAppointment sa = [
            select 
                Id,
                AppointmentNumber,
                ArrivalWindowEndTime,
                ArrivalWindowStartTime,
                ParentRecordId,
                ServiceTerritoryId
            from 
                ServiceAppointment 
            where 
                ParentRecordId = :wo.Id
        ];
        // If arrival window has been set (typically as a result of selecting a time slot, update sa)
        if (jobDetails.start != null){
            // Get timezone of the Service Territory
            ServiceTerritory st = RESTFieldServiceParams.getServiceTerritory();
            System.TimeZone tz = TimeZone.getTimeZone(st.OperatingHours.TimeZone);
            // The datetime values are indicated as UTC, but actually they are in the timezone
            // of the ST, so need to correct them!
            sa.ArrivalWindowStartTime = changeTimeZoneToGmt(jobDetails.start, tz);
            sa.ArrivalWindowEndTime = changeTimeZoneToGmt(jobDetails.finish, tz);
            update sa;
        }
        // Return object
        createSA.sa = sa;
        createSA.timeInMs = (System.now().getTime() - start);
        // Set response body
        res.responseBody = Blob.valueOf(JSON.serialize(createSA));
        return;
    }  

    // Convert datetime to GMT value according to provided timezone
    public static DateTime changeTimeZoneToGmt(DateTime dt, TimeZone tz) {
        Integer offset = tz.getOffset(dt);
        return DateTime.newInstance(dt.getTime() - offset);
    }    

}