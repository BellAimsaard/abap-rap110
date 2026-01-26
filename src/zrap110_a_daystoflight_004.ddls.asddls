@EndUserText.label: 'Abstract entity for Days To Flight'
//The CDS abstract entity ZRAP110_A_DAYSTOFLIGHT_### provided in your exercise package ZRAP110_### 
//will be used to define the type of the return structure of the result parameter.
define abstract entity ZRAP110_A_DaysToFlight_004
{
  initial_days_to_flight : abap.int4;
  remaining_days_to_flight : abap.int4;
  booking_status_indicator : abap.int4;
  days_to_flight_indicator : abap.int4;
}
