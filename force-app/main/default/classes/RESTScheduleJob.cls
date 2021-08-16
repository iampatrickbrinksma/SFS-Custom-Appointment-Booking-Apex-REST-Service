@RestResource(urlMapping='/scheduleJob/*')
global without sharing class RESTScheduleJob {

    @HttpPost
    global static void doPost() {
        // Measure performance
        Long start = System.now().getTime();
        // REST Context
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        // Return object
        RESTObjects.scheduleSA scheduleSA = new RESTObjects.scheduleSA();
        // Get Request Body and convert to object
        System.debug(req.requestBody.toString());
        RESTObjects.jobDetails jobDetails = (RESTObjects.jobDetails)JSON.deserialize(req.requestBody.toString(), RESTObjects.jobDetails.class);                
        // Measure inner REST API call performance
        Long startInnerREST = System.now().getTime();
        // Prepare inner REST API callout to create WO + SA
        Http http = new Http();
        HttpResponse response = new HTTPResponse();
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
        response = http.send(request); 
        // Parse results
        RESTObjects.createSA createSA = (RESTObjects.createSA)JSON.deserialize(response.getBody(), RESTObjects.createSA.class);
        scheduleSA.createSAtimeInMs = createSA.timeInMs;
        // Measure inner REST API call performance
        scheduleSA.innerRESTtimeInMs = (System.now().getTime() - startInnerREST);
        // Schedule appointment
        Id schedPolId = RESTFieldServiceParams.getSchedulingPolicyId();
        FSL.ScheduleResult schedResult = new FSL.ScheduleResult();
        schedResult = FSL.ScheduleService.schedule(schedPolId, createSA.sa.Id);
        // Process results
        if (schedResult == null){
            scheduleSA.result = 'Failed';
        } else {
            scheduleSA.result = 'Success';
            scheduleSA.sa = schedResult.Service;
            scheduleSA.sr = schedResult.Resource;
        }
        // Measure performance
        scheduleSA.scheduleSAtimeInMs = (System.now().getTime() - start);
        // Set response
        res.responseBody = Blob.valueOf(JSON.serialize(scheduleSA));        
        // Return void
        return;
    }

}