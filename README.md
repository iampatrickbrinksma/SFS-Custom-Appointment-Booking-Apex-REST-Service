# Salesforce Field Service Appointment Booking via Apex REST Services

## Introduction

With Salesforce Field Service you can book appointments. You can expose this functionality via Apex REST services to retrieve available time slots, select a time slot, and schedule the appointment. In order to calculate travel time, the FSL Managed Package performs a callout. One of the Salesforce platform limitations is that you cannot perform a callout when there are pending transactions. This results in the requirement to have the creation of the Work Order and Service Appointment in its own transaction, and retrieving the available time slots also in its own transaction respectively.
\
\
The sequence diagram below shows a way to achieve this by using an "inner REST call" to create the Work Order and Service Appointment while the "outer REST call" - the Apex REST Service the client calls - retrieves the available time slots.
\
\
<img src="https://i.imgur.com/qIloZ5m.png" width="800"/>
\
\
## Components

The following Apex Classes are part of the metadata:

* RESTObjects - Provides inner classes to represent the request and response structures
* RESTFieldServiceParams - Provides some util methods. IMPORTANT: Please change the values that match your Salesforce Field Service setup including Service Territory, Operating Hours and Scheduling Policy
* RESTCreateJobDetails - This represents the "Inner REST API" to create/update data (Work Order / Service Appointment). This logic assumes you provide a Work Type which has the Auto-Create Appointment set to true
* RESTGetSlots - This represents the "Outer REST API" for retrieving available time slots for an appointment
* RESTScheduleJob - This represents the "Outer REST API" for scheduling an appointment given a selected time slot
* RESTException - Custom Exception class

*IMPORTANT: This example code is not meant to be deployed to a Salesforce production environment. It needs to be adjusted to the specific requirements and logic and additionally Apex Test Classes need to be developed.*

## How To Use

Once you deployed the code to your org and adjusted the values in the Apex Class RESTFieldServiceParams use a REST API Client of choice (Workbench or PostMan) to send REST API requests and see the responses. See the following sections for an example.

### Field Service Routing Settings

Field Service Settings → Scheduling → Routing, make sure that "Enable Street Level Routing" - to use SLR - is set to true and optionally "Enable Point-to-Point Predictive Routing" - to use P2P - also to true.

### Clear SLR Cache

To force the FSL Managed Package code to make a callout for travel time calculation, execute the following Apex code from the developer console:

    List<FSL__SLR_Cache__c> c = [select Id from FSL__SLR_Cache__c];
    delete c;

This deletes all the records in the SLR Cache object.

### Get Available Time Slots

REST API: /services/apexrest/getSlots
Example Request JSON:

    {
        "worktype": "Maintenance",
        "subject": "Yearly boiler maintenance",
        "description": "Maintenance Work Order for yearly boiler maintenance",
        "street": "Kalverstraat 20",
        "postalcode": "5223 AD",
        "city": "'s-Hertogenbosch",
        "country": "NL"
    }

*Note: The Work Type needs to be created in the org with the auto-create appointment set to true*

Example Response JSON:

    {
    "timezoneid":"Europe/Amsterdam",
    "timezone":"Europe/Amsterdam",
    "slots":[
    {
    "startandfinish":"TimeInterval:[2021-07-02 09:00:00,2021-07-02 11:00:00]",
    "start":"2021-07-02T09:00:00.000Z",
    "grade":82.2243651371010689103726176803343,
    "finish":"2021-07-02T11:00:00.000Z"
    },
    {
    "startandfinish":"TimeInterval:[2021-07-02 11:00:00,2021-07-02 13:00:00]",
    "start":"2021-07-02T11:00:00.000Z",
    "grade":82.2440529238897452751260992997386,
    "finish":"2021-07-02T13:00:00.000Z"
    },
    {
    "startandfinish":"TimeInterval:[2021-07-02 13:00:00,2021-07-02 15:00:00]",
    "start":"2021-07-02T13:00:00.000Z",
    "grade":81.9978971104566708849211825771274,
    "finish":"2021-07-02T15:00:00.000Z"
    },
    {
    "startandfinish":"TimeInterval:[2021-07-02 15:00:00,2021-07-02 17:00:00]",
    "start":"2021-07-02T15:00:00.000Z",
    "grade":81.6142776609505809261602733990321,
    "finish":"2021-07-02T17:00:00.000Z"
    },
    {
    "startandfinish":"TimeInterval:[2021-07-05 09:00:00,2021-07-05 11:00:00]",
    "start":"2021-07-05T09:00:00.000Z",
    "grade":53.9831706459387409640855783258130,
    "finish":"2021-07-05T11:00:00.000Z"
    },
    {
    "startandfinish":"TimeInterval:[2021-07-05 11:00:00,2021-07-05 13:00:00]",
    "start":"2021-07-05T11:00:00.000Z",
    "grade":69.0978549279115117803139285828458,
    "finish":"2021-07-05T13:00:00.000Z"
    },
    {
    "startandfinish":"TimeInterval:[2021-07-05 13:00:00,2021-07-05 15:00:00]",
    "start":"2021-07-05T13:00:00.000Z",
    "grade":68.7973530257984079792845497266711,
    "finish":"2021-07-05T15:00:00.000Z"
    }
    ],
    "result":"Success",
    "innerRESTtimeInMs":1754,
    "getSlotstimeInMs":5544,
    "createSAtimeInMs":1403
    }

*Note: The Work Order and Service Appointment are deleted as part of the logic.*

### Schedule Appointment

REST API: /services/apexrest/scheduleJob
Example Request JSON:

    {
        "worktype": "Maintenance",
        "subject": "Yearly boiler maintenance",
        "description": "Maintenance Work Order for yearly boiler maintenance",
        "street": "Kalverstraat 20",
        "postalcode": "5223 AD",
        "city": "'s-Hertogenbosch",
        "country": "NL",
        "start": "2021-07-02T07:00:00.000Z",
        "finish": "2021-07-02T09:00:00.000Z"
    }

*Note: The datetime values for start and finish (Arrival Window Start / End) are in UTC*

Example Response JSON:

    {
    "sr": {
        "attributes": {
        "type": "ServiceResource",
        "url": "/services/data/v52.0/sobjects/ServiceResource/0Hn7R000000025iSAA"
        },
        "Id": "0Hn7R000000025iSAA",
        "Name": "Lee Ephrati",
        "IsActive": true,
        "IsCapacityBased": false,
        "RelatedRecordId": "0057R00000AhI9FQAV",
        "ResourceType": "T",
        "ServiceTerritories": {
        "totalSize": 1,
        "done": true,
        "records": [
            {
            "attributes": {
                "type": "ServiceTerritoryMember",
                "url": "/services/data/v52.0/sobjects/ServiceTerritoryMember/0Hu7R0000004EJrSAM"
            },
            "ServiceResourceId": "0Hn7R000000025iSAA",
            "Id": "0Hu7R0000004EJrSAM",
            "ServiceTerritoryId": "0Hh7R000000LL4VSAW",
            "FSL__Internal_SLR_HomeAddress_Geolocation__c": null,
            "EffectiveStartDate": "2021-03-04T18:28:00.000+0000",
            "TerritoryType": "P",
            "ServiceTerritory": {
                "attributes": {
                "type": "ServiceTerritory",
                "url": "/services/data/v52.0/sobjects/ServiceTerritory/0Hh7R000000LL4VSAW"
                },
                "Id": "0Hh7R000000LL4VSAW",
                "FSL__Internal_SLR_Geolocation__c": {
                "latitude": 52.095321,
                "longitude": 5.110574
                },
                "FSL__Internal_SLR_Geolocation__Latitude__s": 52.095321,
                "FSL__Internal_SLR_Geolocation__Longitude__s": 5.110574,
                "Longitude": 5.109362336750483,
                "Latitude": 52.09578974451693,
                "OperatingHoursId": "0OH2X000000Xz58WAC",
                "OperatingHours": {
                "attributes": {
                    "type": "OperatingHours",
                    "url": "/services/data/v52.0/sobjects/OperatingHours/0OH2X000000Xz58WAC"
                },
                "Id": "0OH2X000000Xz58WAC",
                "TimeZone": "Europe/Amsterdam"
                }
            }
            }
        ]
        }
    },
    "scheduleSAtimeInMs": 5091,
    "sa": {
        "attributes": {
        "type": "ServiceAppointment",
        "url": "/services/data/v52.0/sobjects/ServiceAppointment/08p7R0000003FFYQA2"
        },
        "Id": "08p7R0000003FFYQA2",
        "Status": "None",
        "FSL__Same_Day__c": false,
        "FSL__Same_Resource__c": false,
        "AppointmentNumber": "SA-1769",
        "DueDate": "2021-07-15T16:59:00.000+0000",
        "EarliestStartTime": "2021-07-01T16:59:00.000+0000",
        "Duration": 30.0,
        "DurationType": "Minutes",
        "Latitude": 51.697694,
        "Longitude": 5.29341,
        "FSL__InternalSLRGeolocation__Latitude__s": 51.698257,
        "FSL__InternalSLRGeolocation__Longitude__s": 5.294612,
        "ServiceTerritoryId": "0Hh7R000000LL4VSAW",
        "FSL__Schedule_over_lower_priority_appointment__c": false,
        "FSL__Use_Async_Logic__c": false,
        "FSL__IsMultiDay__c": false,
        "ParentRecordId": "0WO7R000002GmjEWAS",
        "ArrivalWindowStartTime": "2021-07-02T07:00:00.000+0000",
        "ArrivalWindowEndTime": "2021-07-02T09:00:00.000+0000",
        "Not_Emergency__c": true,
        "ServiceTerritory": {
        "attributes": {
            "type": "ServiceTerritory",
            "url": "/services/data/v52.0/sobjects/ServiceTerritory/0Hh7R000000LL4VSAW"
        },
        "Id": "0Hh7R000000LL4VSAW",
        "OperatingHoursId": "0OH2X000000Xz58WAC",
        "OperatingHours": {
            "attributes": {
            "type": "OperatingHours",
            "url": "/services/data/v52.0/sobjects/OperatingHours/0OH2X000000Xz58WAC"
            },
            "Id": "0OH2X000000Xz58WAC",
            "TimeZone": "Europe/Amsterdam"
        }
        },
        "FSL__Emergency__c": false,
        "SchedStartTime": "2021-07-02T07:00:00.000+0000",
        "SchedEndTime": "2021-07-02T07:30:00.000+0000",
        "FSL__Schedule_Mode__c": "Automatic",
        "FSL__Scheduling_Policy_Used__c": "a0a2X00000Pyh6nQAB"
    },
    "result": "Success",
    "innerRESTtimeInMs": 940,
    "createSAtimeInMs": 658
    }

*Note: To validate that the travel time calculation method was SLR or P2P - depending on your setting - check the value of the following fields on the Assigned Resource object:*

* *Estimated Travel Time From Source*
* *Estimated Travel Time To Source*

*Depending on the appointment it will have both travel to and from, or just travel to or from. The value should be "SLR" or "Predictive" (for P2P)*

## Considerations

### Transaction Control

As the "inner" REST API call has its own transaction context and the DML is committed to the database when the call is finished, the "outer" REST API service needs to include some sort of transaction control when exceptions occur. 

### Performance Overhead

The "inner" REST API call does case some overhead with regard to performance. Preparing the callout, serialising and deserialising the data do add up to the total run time. However, the first tests seem to show that this overhead is 200-400ms (tested on a Salesforce demo org). This seems reasonable on a total runtime of typically >5 seconds, especially considering the benefits of being able to use SLR or P2P.

### Error Handling

This pattern consists of an additional "internal" REST API call which has its own transaction context. The proper error handling needs to be implemented to make sure the client is informed about any functional or technical exceptions that occurred.

### API Limits

REST API limits apply also to the REST API callouts being made from the org to the org itself. Consider the increase in API limit consumption when implementing this pattern.

### Scalability

The transactions as part of this pattern are synchronous, and the governor limits for synchronous transactions apply (see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm). Getting available time slots and scheduling appointments in Salesforce Field Service tend to take some time, and need to be tuned in order to limit the total transactions times. 
If scale is a concern (e.g. longer transaction times, high volume of parallel requests), it is recommended to look for a different pattern which involves a middleware platform to break up the transactions orchestrated by the middleware platform and possibly run transactions in an asynchronous manner to avoid hitting governor limits.
