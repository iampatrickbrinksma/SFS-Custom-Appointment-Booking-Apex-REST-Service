## Introduction

>Please read this knowledge article: https://help.salesforce.com/s/articleView?id=000396257&type=1

When Salesforce Field Service retrieves the available time slots when booking an appointment, gets the qualified and available candidates for an appointment or schedules an appointment the Field Service managed package performs a callout to calculate the travel times. This callout is performed when Street Level Routing (SLR) or Point-to-Point Predictive (P2P) is enabled in the Field Service Settings, and the specific travel routes are not cached in the SLR Cache object. This is valid for the legacy scheduling and optimization service, also referred to as LS.
When using the new Enhanced Scheduling and Optimization (ES&O) a callout is performed with every scheduling and optimization operations, including the validation of work rules on the Gantt. ES&O always uses P2P for travel time calculations which is performed within the ES&O service.
In both scenarios it is possible that the following exception is thrown:

>['You have uncommitted work pending. Please commit or rollback before calling out'](https://help.salesforce.com/s/articleView?id=000385708&type=1)

This happens typically when custom logic is implemented to retrieve available time slots, get qualified and available candidates, and schedule appointments. When using the Global Actions or the Dispatcher Console, this is not an issue, as the FSL Managed Package components manage the transactions in a way that the callout can be made. However, when a customer implements their custom logic and utilizes the [FSL Managed Package Apex methods](https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_namespace_FSL.htm) it is possible that the customer encounters the exception. When using LS there is the option in the Field Service Settings tab to revert to aerial travel time calculations when this exception is thrown. When using ES&O, there is no fallback option and the exception will be raised preventing the operation from being completed successfully!
The issue is typically encountered when a new Work Order and/or Service Appointment are created or updated as part of the same transaction during which the FSL Managed Package Apex methods are used to get available candidates (FSL.GradeSlotsService.getGradedMatrix), retrieve available time slots (FSL.AppointmentBooking.getSlots) or schedule (FSL.ScheduleService.schedule) an appointment. This scenario is often implemented when these methods are exposed via a custom REST or SOAP API or when custom logic is implemented to replace the available Global Actions.

As mentioned in the [Limits and Limitations for Enhanced Scheduling and Optimization](https://help.salesforce.com/s/articleView?id=sf.pfs_enhanced_available_limits.htm&type=5) help document, the DML transaction needs to be separated from the callout, which is only possible by having one transaction perform the DML and another transaction performing the callout. This document describes a pattern whereby the transaction of creating and/or updating data is separated from the transaction that performs the callout to perform travel time calculations (LS) or scheduling and optimization actions (ES&O). The example used to illustrate the solution is the scenario in which the ability to get available time slots and schedule an appointment is exposed via the Salesforce Apex REST API.

>Make sure to read the “Considerations” section below before applying this pattern, as it is not meant as a best practice for all scenarios.

## Callout Exception

When using LS, the callout exception occurs when travel times are requested. When using ES&O, the callout exception occurs when retrieving available time slots. Both scenarios are shown in the sequence diagrams below. In both scenarios there is uncommitted work (creation of a work order and a service appointment) as part of the REST API transaction, so a callout is not allowed by the Salesforce platform.
When using LS, depending on the value of the Field Service setting "Avoid aerial calculation upon callout DML exception" the logic will either revert to aerial calculation or throw the exception. If aerial calculation is used, the resulting schedule is likely to have non-realistic travel times and this can lead to a less optimal schedule and the need for manual interventions to correct the schedule.

![image](https://github.com/iampatrickbrinksma/SFS-Custom-Appointment-Booking-Apex-REST-Service/assets/78381570/613e2df7-0514-477b-9a43-b242ee429314)

When using ES&O, a callout that is necessary to retrieve the available time slots is not possible, and the flow is interrupted as shown below. 

![image](https://github.com/iampatrickbrinksma/SFS-Custom-Appointment-Booking-Apex-REST-Service/assets/78381570/608bf777-7847-49e4-ad62-da189e4abc85)

## Separate Transactions Using an "Inner" REST API Callout

One way to separate the transactions of performing the DML and the callout is to expose the logic that performs the DML as an Apex REST service which is called from the logic performing the callout. This is shown in the sequence diagrams below. The client calls the Apex REST Service to request the available time slots, and the Apex REST Service uses another "Inner" Apex REST Service to create and/or update the necessary data (Work Order and Service Appointment). Due to this construction, the creation and/or update of the data is committed in its own transaction allowing the FSL Managed Package to perform a callout to retrieve the travel times or to call the ES&O service.
When using LS, the result is that when using SLR or P2P for travel time calculation, Field Service doesn't have to fall back to aerial calculation due to the callout, and more accurate travel times are used. When using ES&O, the result is that available slots can be retrieved, and an appointment can be scheduled.

Diagram for LS:
![image](https://github.com/iampatrickbrinksma/SFS-Custom-Appointment-Booking-Apex-REST-Service/assets/78381570/97af0ae1-0205-4570-8eaf-13aa191364b2)

Diagram for ES&O:
![image](https://github.com/iampatrickbrinksma/SFS-Custom-Appointment-Booking-Apex-REST-Service/assets/78381570/34f0a48e-2768-4a22-af51-3be2456e85e5)

## Example Code

>**IMPORTANT**: This example code is not meant to be deployed to a Salesforce production environment. The purpose is to show a working example of separating the DML transaction from the callout.

Before deploying the code please follow the steps to create a way to call the REST API of the same Salesforce org in an authenticated way as described in the section “Setup Salesforce to Salesforce integration” below.

Then adjust the value of the named credentials used in the Apex Classes RESTGetSlots and RESTScheduleJob to the ones you created.

The following Apex Classes are part of the metadata:

* RESTObjects - Provides inner classes to represent the request and response structures
* RESTFieldServiceParams - Provides some util methods. IMPORTANT: Please change the values that match your Salesforce Field Service setup including Service Territory, Operating Hours, and Scheduling Policy
* RESTCreateJobDetails - This represents the "Inner REST API" to create/update data (Work Order / Service Appointment). This logic assumes you provide a Work Type which has the Auto-Create Appointment set to true
* RESTGetSlots - This represents the "Outer REST API" for retrieving available time slots for an appointment
* RESTScheduleJob - This represents the "Outer REST API" for scheduling an appointment given a selected time slot

## How To Use

Once you deployed the code to your org, set up the org to the same org connection and adjusted the values in the Apex Class RESTFieldServiceParams, and use a REST API Client of choice (Workbench or PostMan) to send REST API requests and see the responses. See the following sections for an example. This example assumes the use of LS to show how this works with calculating travel times. When ES&O is used, skip to section: “Get Available Time Slots”.

### Field Service Routing Settings

Field Service Settings → Scheduling → Routing, make sure that "Enable Street Level Routing" - to use SLR - is set to true and optionally "Enable Point-to-Point Predictive Routing" - to use P2P - also to true.

### Clear SLR Cache

To force the FSL Managed Package code to make a callout for travel time calculation, execute the following Apex code from the developer console:

```
List<FSL__SLR_Cache__c> c = [select Id from FSL__SLR_Cache__c];
delete c;
```

This deletes all the records in the SLR Cache object.

### How To Call the REST API

It’s important to know that you can’t call the ‘getSlots’ or ‘scheduleJob’ REST endpoints from within a Salesforce org, as that will result in the following exception:

```
[{"errorCode":"APEX_ERROR","message":"System.CalloutException: 
Callout loop not allowed\n\nClass.RESTGetSlots.doPost: line 30, column 1"}]
```

This is because the flow of callouts in this situation is Salesforce Org → Salesforce Org → Salesforce Org, which is not allowed. 
Use either PostMan, Workbench, or another tool to call the Salesforce Apex REST API.

### Get Available Time Slots

REST API: /services/apexrest/getSlots
Request:

```
{
    "worktype": "Maintenance",
    "subject": "Inner REST API Call Test",
    "description": "Testing 1,2,3...",
    "street": "Av. del Monasterio de El Escorial, 36A",
    "postalcode": "28949",
    "city": "Madrid",
    "country": "Spain"
}
```

Note: The Work Type needs to be created in the org with the auto-create appointment set to true

Response:

```
{
   "totalDurationInMs":3904,
   "timezoneOffSet":7200000,
   "timezoneid":"Europe/Madrid",
   "timezone":"Europe/Madrid",
   "slots":[
      {
         "startandfinish":"TimeInterval:[2023-08-25 13:00:00,2023-08-25 17:00:00]",
         "start":"2023-08-25T13:00:00.000Z",
         "grade":100.0,
         "finish":"2023-08-25T17:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-28 09:00:00,2023-08-28 13:00:00]",
         "start":"2023-08-28T09:00:00.000Z",
         "grade":58.18013761938995,
         "finish":"2023-08-28T13:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-28 13:00:00,2023-08-28 17:00:00]",
         "start":"2023-08-28T13:00:00.000Z",
         "grade":55.61261168737804,
         "finish":"2023-08-28T17:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-29 09:00:00,2023-08-29 13:00:00]",
         "start":"2023-08-29T09:00:00.000Z",
         "grade":44.366848105165865,
         "finish":"2023-08-29T13:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-29 13:00:00,2023-08-29 17:00:00]",
         "start":"2023-08-29T13:00:00.000Z",
         "grade":41.593920098592996,
         "finish":"2023-08-29T17:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-30 09:00:00,2023-08-30 13:00:00]",
         "start":"2023-08-30T09:00:00.000Z",
         "grade":29.577898736777243,
         "finish":"2023-08-30T13:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-30 13:00:00,2023-08-30 17:00:00]",
         "start":"2023-08-30T13:00:00.000Z",
         "grade":26.804970730204374,
         "finish":"2023-08-30T17:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-31 09:00:00,2023-08-31 13:00:00]",
         "start":"2023-08-31T09:00:00.000Z",
         "grade":14.788949368388614,
         "finish":"2023-08-31T13:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-08-31 13:00:00,2023-08-31 17:00:00]",
         "start":"2023-08-31T13:00:00.000Z",
         "grade":12.01602136181576,
         "finish":"2023-08-31T17:00:00.000Z"
      },
      {
         "startandfinish":"TimeInterval:[2023-09-01 09:00:00,2023-09-01 13:00:00]",
         "start":"2023-09-01T09:00:00.000Z",
         "grade":0.0,
         "finish":"2023-09-01T13:00:00.000Z"
      }
   ],
   "result":"Success",
   "innerRESTtimeInMs":1470,
   "getSlotstimeInMs":3577,
   "deleteJobInMs":327,
   "createSAtimeInMs":1040
}
```

Note: The Work Order and Service Appointment are deleted as part of the logic. 

### Schedule Appointment

REST API: /services/apexrest/scheduleJob
Request:

```
{
    "worktype": "Maintenance",
    "subject": "Inner REST API Call Test",
    "description": "Testing 1,2,3...",
    "street": "Av. del Monasterio de El Escorial, 36A",
    "postalcode": "28949",
    "city": "Madrid",
    "country": "Spain",
    "start": "2023-08-28T07:00:00.000Z",
    "finish": "2023-08-28T11:00:00.000Z"
}
```

Note: The datetime values for start and finish (Arrival Window Start / End) are in UTC!

Response:

```
{
   "sr":{
      "attributes":{
         "type":"ServiceResource",
         "url":"/services/data/v58.0/sobjects/ServiceResource/0Hn0600000003jDCAQ"
      },
      "ServiceTerritories":{
         "totalSize":0,
         "done":false,
         "records":[
            
         ]
      },
      "ServiceCrewMembers":{
         "totalSize":0,
         "done":false,
         "records":[
            
         ]
      },
      "ServiceResourceCapacities":{
         "totalSize":0,
         "done":false,
         "records":[
            
         ]
      },
      "ServiceResourceSkills":{
         "totalSize":0,
         "done":false,
         "records":[
            
         ]
      },
      "Id":"0Hn0600000003jDCAQ",
      "ShiftServiceResources":{
         "totalSize":0,
         "done":false,
         "records":[
            
         ]
      }
   },
   "scheduleSAtimeInMs":5640,
   "sa":{
      "attributes":{
         "type":"ServiceAppointment",
         "url":"/services/data/v58.0/sobjects/ServiceAppointment/08p060000003HtxAAE"
      },
      "SchedEndTime":"2023-08-28T09:37:00.000+0000",
      "SchedStartTime":"2023-08-28T08:37:00.000+0000",
      "Id":"08p060000003HtxAAE",
      "ServiceResources":{
         "totalSize":0,
         "done":false,
         "records":[
            
         ]
      }
   },
   "result":"Success",
   "innerRESTtimeInMs":1435,
   "createSAtimeInMs":1031
}
```

The screenshot below shows that the travel time calculation method that was used is P2P (Predictive) which was achieved by being able to perform the callout from the FSL Managed Package code.

![image](https://github.com/iampatrickbrinksma/SFS-Custom-Appointment-Booking-Apex-REST-Service/assets/78381570/5913386f-3fb5-470f-b3fc-453dbfa9172d)

## Considerations

### **Middleware**

Consider using a middleware platform to separate the transactions encapsulated in a composite service.

### Callout Loop Exception

The "outer" REST API logic cannot be called from the same or another Salesforce. This will result in the Callout Loop exception as described here: https://help.salesforce.com/s/articleView?id=000340086&type=1.
The "inner" REST API logic cannot contain an additional callout (e.g. to geocode the address using a 3rd party provider), as the Salesforce platform does not allow a so-called Callout Loop. For more details, please read https://help.salesforce.com/s/articleView?id=000340086&type=1.

### Transaction Control

As the "inner" REST API call has its own transaction context and the DML is committed to the database when the call is finished, the "outer" REST API service needs to include some sort of transaction control when exceptions occur. 

### Performance Overhead

The "inner" REST API call does cause some overhead with regard to performance. Preparing the callout, serializing, and deserializing the data do add up to the total run time. The example described in this document measure the performance of the individual steps and shows it in the API response.

### Error Handling

This pattern consists of an additional "internal" REST API call which has its own transaction context. Proper error handling needs to be implemented to make sure the client is informed about any functional or technical exceptions that occur.

### API Limits

REST API limits apply also to the REST API callouts being made from the org to the org itself. Consider the increase in API limit consumption when implementing this pattern.

### Scalability

The transactions as part of this pattern are synchronous, and the governor limits for synchronous transactions apply (see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm). Getting available time slots and scheduling appointments in Salesforce Field Service tend to take some time and need to be tuned in order to limit the total transaction times. 
If the scale is a concern (e.g. longer transaction times, high volume of parallel requests), it is recommended to look for a different pattern that involves a middleware platform to break up the transactions orchestrated by the middleware platform and possibly run transactions in an asynchronous manner to avoid hitting governor limits.

## Appendix

### Set up a Salesforce to Salesforce Connection

In order for an Apex callout to be able to call an API endpoint in the same org, it is necessary to set up a Connected App, an Authentication Provider, and Named Credentials using a named principal:

Connected App

1. Navigate to Setup → App Manager
2. Click the “Create Connected App” button to create a new Connected App
3. Give it a descriptive name, in this example "SalesforceSameOrg"
4. The API name is auto-populated
5. Provide an email address
6. Enable OAuth Settings
7. When creating the connected app use "https://www.login.salesforce.com/services/authcallback" as a placeholder. This will be updated later with the correct callback URL from the Authentication Provider
8. For OAuth scopes, select
    1. Access the identity URL service (id, profile, email, address, phone)
    2. Manager user data via API (api)
    3. Perform requests at any time (refresh_token, offline_access)
9. Make sure the “Require Secret for Web Server Flow” and “Require Secret for Refresh Token Flow” are checked
10. Save

Once saved, it can take some time for the changes to be applied. In the meantime continue creating the Authentication Provider so the callback URL for the connected app can be updated.

Authentication Provider

1. Navigate to Setup → Auth. Provider
2. Create a New Authentication Provider
3. Give it a name, in the example “SalesforceSameOrg”
4. Select “Salesforce” as Provider Type
5. Use the Consumer Key and Secret from the Connected App created earlier
6. Authorize Endpoint URL: https://login.salesforce.com/services/oauth2/authorize
7. Token Endpoint URL: https://login.salesforce.com/services/oauth2/token
8. Default scope: “api refresh_token”
9. Save

Copy the "Callback URL" and set the value of the Callback URL in the earlier created Connected AppIt can take up to 10 minutes for the changes to be applied.

Copy the "Test-Only Initialization URL" from the Authentication Provider and paste the URL into a browser window. If the setup is correct, you should be redirected to a login screen, and after you log in you authorize the Connected App. If you are not redirected to the login screen, give it some more time and try again. If it doesn't work by then, please review your configuration.

Named Credentials

1. Navigate to Setup → Named Credentials
2. Click New Legacy
3. Select the Authentication Provider created earlier
4. Select OAuth 2.0 as the protocol and use the URL of the org (https://<My Domain>.[my.salesforce.com](http://my.salesforce.com/))
5. Select Named Principal as Identity Type
6. Save and authenticate the Named Credentials with the “Named Principal” user you want to use for the API calls

The Named Credential name is referenced in the Apex Classes performing the REST API callout. Please update the code with the name you have used.


>Note: It is strongly recommended to use the new way of creating Named Credentials as described in the [help documentation](https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm&type=5). The legacy way will be deprecated in a future release!

### Plant UML Diagrams Source

The sequence diagrams in this document were made with [http://www.plantuml.com](http://www.plantuml.com/), and for reference, the UML code is copied here:

First diagram:

```
@startuml
actor Customer
participant Client
participant REST as "Salesforce REST API"
participant FSL as "FSL Managed Package"
participant Travel as "Travel Time Calculation Provider"
Customer -> Client: Enter appointment details
Client -> REST: Request Time Slots
REST -> REST: Create Work Order and Service Appointment
REST -> FSL: Request Available Time Slots (getSlots)
FSL -> Travel: Request Travel Times (Callout)\nCallout Exception
Destroy Travel
FSL -> FSL: Use Aerial To Calculate Travel Times
FSL -> REST: Provide Available Time Slots (getSlots)
REST -> REST: Delete Work Order and Service Appointment
REST -> Client: Available Time Slots
REST -> REST: Transaction Committed
Client -> Customer: Show Available Time Slots
Customer -> Customer: Select Available Time Slot\nTo Schedule Appointment
Customer -> Client: Schedule Appointment\nAt Selected Time Slot
Client -> REST: Schedule Appointment\nAt Selected Time Slot
REST -> REST: Create Work Order and Service Appointment\nUpdate Service Appointment with Arrival Window
REST -> FSL: Request To Schedule Appointment (ScheduleService)
FSL -> Travel: Request Travel Times (Callout)\nCallout Exception
Destroy Travel
FSL -> FSL: Use Aerial To Calculate Travel Times
FSL -> REST: Provide Scheduling Results (ScheduleService)
REST -> Client: Provide Scheduling Results
REST -> REST: Transaction Committed
Client -> Customer: Show Scheduling Results
@enduml
```

Second diagram:

```
@startuml
actor Customer
participant Client
participant REST as "Salesforce REST API"
participant FSL as "FSL Managed Package"
participant ESO as "Enhanced Scheduling & Optimization service"
Customer -> Client: Enter appointment details
Client -> REST: Request Time Slots
REST -> REST: Create Work Order and Service Appointment
REST -> FSL: Request Available Time Slots (getSlots)
FSL -> ESO: Request Available Time Slots (Callout)\nCallout Exception
Destroy ESO
@enduml
```

Third diagram:

```
@startuml
actor Customer
participant Client
participant OuterREST as "Salesforce REST API (Outer)"
participant InnerREST as "Salesforce REST API (Inner)"
participant FSL as "FSL Managed Package"
participant Travel as "Travel Time Calculation Provider"
Customer -> Client: Enter appointment details
Client -> OuterREST: Request Time Slots
OuterREST -> InnerREST: Create Work Order and Service Appointment
InnerREST -> OuterREST: Return Service Appointment Details
InnerREST -> InnerREST: Transaction Committed\n Due To REST API Call
OuterREST -> FSL: Request Available Time Slots (getSlots)
FSL -> Travel: Request Travel Times (Callout)
Travel -> FSL: Provide Travel Times
FSL -> OuterREST: Provide Available Time Slots (getSlots)
OuterREST -> OuterREST: Delete Work Order and Service Appointment
OuterREST -> Client: Available Time Slots
OuterREST -> OuterREST: Transaction Committed
Client -> Customer: Show Available Time Slots
Customer -> Customer: Select Available Time Slot\nTo Schedule Appointment
Customer -> Client: Schedule Appointment\nAt Selected Time Slot
Client -> OuterREST: Schedule Appointment\nAt Selected Time Slot
OuterREST -> InnerREST: Create Work Order and Service Appointment\nUpdate Service Appointment with Arrival Window
InnerREST -> OuterREST: Return Service Appointment Details
InnerREST -> InnerREST: Transaction Committed\n Due To REST API Call
OuterREST -> FSL: Request To Schedule Appointment (ScheduleService)
FSL -> Travel: Request Travel Times (Callout)
Travel -> FSL: Provide Travel Times
FSL -> OuterREST: Provide Scheduling Results (ScheduleService)
OuterREST -> Client: Provide Scheduling Results
OuterREST -> OuterREST: Transaction Committed
Client -> Customer: Show Scheduling Results
@enduml
```

Fourth diagram:

```
@startuml
actor Customer
participant Client
participant OuterREST as "Salesforce REST API (Outer)"
participant InnerREST as "Salesforce REST API (Inner)"
participant FSL as "FSL Managed Package"
participant ESO as "Enhanced Scheduling & Optimization service"
Customer -> Client: Enter appointment details
Client -> OuterREST: Request Time Slots
OuterREST -> InnerREST: Create Work Order and Service Appointment
InnerREST -> OuterREST: Return Service Appointment Details
InnerREST -> InnerREST: Transaction Committed\n Due To REST API Call
OuterREST -> FSL: Request Available Time Slots (getSlots)
FSL -> ESO: Request Available Time Slots (Callout)
ESO -> FSL: Provide Available Time Slots
FSL -> OuterREST: Provide Available Time Slots (getSlots)
OuterREST -> OuterREST: Delete Work Order and Service Appointment
OuterREST -> Client: Available Time Slots
OuterREST -> OuterREST: Transaction Committed
Client -> Customer: Show Available Time Slots
Customer -> Customer: Select Available Time Slot\nTo Schedule Appointment
Customer -> Client: Schedule Appointment\nAt Selected Time Slot
Client -> OuterREST: Schedule Appointment\nAt Selected Time Slot
OuterREST -> InnerREST: Create Work Order and Service Appointment\nUpdate Service Appointment with Arrival Window
InnerREST -> OuterREST: Return Service Appointment Details
InnerREST -> InnerREST: Transaction Committed\n Due To REST API Call
OuterREST -> FSL: Request To Schedule Appointment (ScheduleService)
FSL -> ESO: Request To Schedule Appointment (Callout)
ESO -> FSL: Provide Scheduling Results
FSL -> OuterREST: Provide Scheduling Results (ScheduleService)
OuterREST -> Client: Provide Scheduling Results
OuterREST -> OuterREST: Transaction Committed
Client -> Customer: Show Scheduling Results
    @enduml
```

