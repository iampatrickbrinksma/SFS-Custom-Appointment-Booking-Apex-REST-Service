public class RESTFieldServiceParams {

    // PLEASE UPDATE TO VALID NAMES!
    public final static String SERVICETERRITORY_NAME = 'The Netherlands (Private)';
    public final static String OPERATINGHOURSFORTIMESLOTS_NAME = 'Gold Appointments Calendar';
    public final static String SCHEDULINGPOLICY_NAME = 'Customer First';

    public static ServiceTerritory getServiceTerritory(){
        return [select Id, OperatingHours.TimeZone from ServiceTerritory where Name = :SERVICETERRITORY_NAME];
    }

    public static Id getOperatingHoursId(){
        return [select Id from OperatingHours where Name = :OPERATINGHOURSFORTIMESLOTS_NAME].Id;
    }

    public static Id getSchedulingPolicyId(){
        return [select Id from FSL__Scheduling_Policy__c where Name = :SCHEDULINGPOLICY_NAME].Id;
    }

}