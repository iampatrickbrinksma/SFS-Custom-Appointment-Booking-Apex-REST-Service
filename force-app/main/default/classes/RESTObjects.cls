global class RESTObjects {

    global class createSA {
        global ServiceAppointment sa;
        global Long timeInMs;
    }

    global class scheduleSA {
        global String result;
        global ServiceAppointment sa;
        global ServiceResource sr;
        global Long createSAtimeInMs;
        global Long innerRESTtimeInMs;
        global Long scheduleSAtimeInMs;
    }

    global class jobDetails {
        global String worktype;
        global String subject;
        global String description;
        global String street;
        global String postalcode;
        global String city;
        global String country;
        global DateTime start;
        global DateTime finish;
        global Id stId;
    }

    global class getSlotResults {
        global String result;
        global String timezone;
        global String timezoneid;
        global List<RESTObjects.slot> slots;
        global Long createSAtimeInMs;
        global Long innerRESTtimeInMs;
        global Long getSlotstimeInMs;
    }

    global class slot {
        global Decimal grade;
        global DateTime start;
        global DateTime finish;
        global String startandfinish;
    }

    global class error {
        global String errorCode;
        global String message;
    }

}