CLASS lsc_zrap110_r_traveltp_004 DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS adjust_numbers REDEFINITION.

ENDCLASS.

CLASS lsc_zrap110_r_traveltp_004 IMPLEMENTATION.

  METHOD adjust_numbers.
    DATA: travel_id_max TYPE /dmo/travel_id.

    "Root BO entity: Travel
    IF mapped-travel IS NOT INITIAL.
      TRY.
          "get numbers
          cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr       = '01'
              object            = 'ZRAP110004'  "Fallback: '/DMO/TRV_M'
              quantity          = CONV #( lines( mapped-travel ) )
            IMPORTING
              number            = DATA(number_range_key)
              returncode        = DATA(number_range_return_code)
              returned_quantity = DATA(number_range_returned_quantity)
          ).
        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          RAISE SHORTDUMP TYPE cx_number_ranges
            EXPORTING
              previous = lx_number_ranges.
      ENDTRY.

      ASSERT number_range_returned_quantity = lines( mapped-travel ).
      travel_id_max = number_range_key - number_range_returned_quantity.
      LOOP AT mapped-travel ASSIGNING FIELD-SYMBOL(<travel>).
        travel_id_max += 1.
        <travel>-TravelID = travel_id_max.
      ENDLOOP.
    ENDIF.

    "Child BO entity: Booking
    IF mapped-booking IS NOT INITIAL.
      READ ENTITIES OF ZRAP110_R_TravelTP_004 IN LOCAL MODE
        ENTITY Booking BY \_Travel
          FROM VALUE #( FOR booking IN mapped-booking WHERE ( %tmp-TravelID IS INITIAL )
                                                            ( %pid = booking-%pid
                                                              %key = booking-%tmp ) )
        LINK DATA(booking_to_travel_links).

      LOOP AT mapped-booking ASSIGNING FIELD-SYMBOL(<booking>).
        <booking>-TravelID =
          COND #( WHEN <booking>-%tmp-TravelID IS INITIAL
                  THEN mapped-travel[ %pid = booking_to_travel_links[ source-%pid = <booking>-%pid ]-target-%pid ]-TravelID
                  ELSE <booking>-%tmp-TravelID ).
      ENDLOOP.

      LOOP AT mapped-booking INTO DATA(mapped_booking) GROUP BY mapped_booking-TravelID.
        SELECT MAX( booking_id ) FROM zrap110_abook004 WHERE travel_id = @mapped_booking-TravelID INTO @DATA(max_booking_id) .
        LOOP AT GROUP mapped_booking ASSIGNING <booking>.
          max_booking_id += 10.
          <booking>-BookingID = max_booking_id.
        ENDLOOP.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR Travel
        RESULT result,
      get_instance_features FOR INSTANCE FEATURES
        IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS createTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~createTravel.

    METHODS recalcTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION Travel~recalcTotalPrice.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~calculateTotalPrice.

    METHODS setInitialTravelValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~setInitialTravelValues.

    METHODS validateAgency FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateAgency.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.
ENDCLASS.

CLASS lhc_travel IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD get_instance_features.
  ENDMETHOD.

  METHOD acceptTravel.
  ENDMETHOD.

  METHOD createTravel.
  ENDMETHOD.

  METHOD recalcTotalPrice.
  ENDMETHOD.

  METHOD rejectTravel.
  ENDMETHOD.

  METHOD calculateTotalPrice.
  ENDMETHOD.

  METHOD setInitialTravelValues.
  ENDMETHOD.

  METHOD validateAgency.
    DATA lt_agencies TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id.

    READ ENTITIES OF zrap110_r_traveltp_004 IN LOCAL MODE
        ENTITY Travel
        FIELDS ( AgencyID )
        WITH CORRESPONDING #( keys )
    RESULT DATA(lt_travels).

    " Optimization of DB select: extract distinct non-initial agency IDs
    lt_agencies = CORRESPONDING #( lt_travels DISCARDING DUPLICATES MAPPING agency_id = AgencyID EXCEPT * ).
    DELETE lt_agencies WHERE agency_id IS INITIAL.

    IF  lt_agencies IS NOT INITIAL.
      " check if agency ID exist
      SELECT FROM /dmo/agency FIELDS agency_id
        FOR ALL ENTRIES IN @lt_agencies
        WHERE agency_id = @lt_agencies-agency_id
        INTO TABLE @DATA(agencies_db).
    ENDIF.

    " Raise msg for non existing and initial agency id
    LOOP AT lt_travels INTO DATA(ls_travels).
      APPEND VALUE #(  %tky        = ls_travels-%tky
                       %state_area = 'VALIDATE_AGENCY'
                     ) TO reported-travel.

      IF ls_travels-AgencyID IS INITIAL OR NOT line_exists( agencies_db[ agency_id = ls_travels-AgencyID ] ).
        APPEND VALUE #(  %tky = ls_travels-%tky ) TO failed-travel.
        APPEND VALUE #(  %tky = ls_travels-%tky
                         %state_area = 'VALIDATE_AGENCY'
                         %msg = NEW /dmo/cm_flight_messages(
                                          textid    = /dmo/cm_flight_messages=>agency_unkown
                                          agency_id = ls_travels-AgencyID
                                          severity  = if_abap_behv_message=>severity-error )
                         %element-AgencyID = if_abap_behv=>mk-on
                      ) TO reported-travel.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateCustomer.
    DATA lt_customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    READ ENTITIES OF zrap110_r_traveltp_004 IN LOCAL MODE
        ENTITY Travel
        FIELDS ( customerID )
        WITH CORRESPONDING #( keys )
    RESULT DATA(lt_travels).

    "optimization of DB select: extract distinct non-initial customer IDs
    lt_customers = CORRESPONDING #( lt_travels DISCARDING DUPLICATES MAPPING customer_id = customerID EXCEPT * ).
    DELETE lt_customers WHERE customer_id IS INITIAL.

    IF lt_customers IS NOT INITIAL.
      "check if customer ID exists
      SELECT FROM /dmo/customer FIELDS customer_id
             FOR ALL ENTRIES IN @lt_customers
             WHERE customer_id = @lt_customers-customer_id
        INTO TABLE @DATA(lt_valid_customers).
    ENDIF.

    "raise msg for non existing and initial customer id
    LOOP AT lt_travels INTO DATA(ls_travels).
      APPEND VALUE #(  %tky        = ls_travels-%tky "%tky (Transactional Key)
                       %state_area = 'VALIDATE_CUSTOMER'
                     ) TO reported-travel.

      IF ls_travels-CustomerID IS  INITIAL.
        APPEND VALUE #( %tky = ls_travels-%tky ) TO failed-travel.

        APPEND VALUE #( %tky        = ls_travels-%tky
                        %state_area = 'VALIDATE_CUSTOMER'
                        %msg        = NEW /dmo/cm_flight_messages(
                                        textid   = /dmo/cm_flight_messages=>enter_customer_id
                                        severity = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.

      ELSEIF ls_travels-CustomerID IS NOT INITIAL AND NOT line_exists( lt_valid_customers[ customer_id = ls_travels-CustomerID ] ).
        APPEND VALUE #(  %tky = ls_travels-%tky ) TO failed-travel.

        APPEND VALUE #(  %tky        = ls_travels-%tky
                         %state_area = 'VALIDATE_CUSTOMER'
                         %msg        = NEW /dmo/cm_flight_messages(
                                         customer_id = ls_travels-customerid
                                         textid      = /dmo/cm_flight_messages=>customer_unkown "CustomerID  &1 is unknown.
                                         severity    = if_abap_behv_message=>severity-error )
                         %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.

    READ ENTITIES OF zrap110_r_traveltp_004 IN LOCAL MODE
        ENTITY Travel
        FIELDS ( BeginDate EndDate )
        WITH CORRESPONDING #( keys )
    RESULT DATA(lt_travels).


    LOOP AT lt_travels INTO DATA(ls_travels).
      APPEND VALUE #(  %tky        = ls_travels-%tky
                       %state_area = 'VALIDATE_DATES' ) TO reported-travel.

      IF ls_travels-EndDate < ls_travels-BeginDate.                                 "end_date before begin_date
        APPEND VALUE #( %tky = ls_travels-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = ls_travels-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg = NEW /dmo/cm_flight_messages(
                                   textid     = /dmo/cm_flight_messages=>begin_date_bef_end_date
                                   severity   = if_abap_behv_message=>severity-error
                                   begin_date = ls_travels-BeginDate
                                   end_date   = ls_travels-EndDate
                                   travel_id  = ls_travels-TravelID )
                        %element-BeginDate    = if_abap_behv=>mk-on
                        %element-EndDate      = if_abap_behv=>mk-on
                     ) TO reported-travel.

      ELSEIF ls_travels-BeginDate < cl_abap_context_info=>get_system_date( ).  "begin_date must be in the future
        APPEND VALUE #( %tky        = ls_travels-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = ls_travels-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg = NEW /dmo/cm_flight_messages(
                                    textid   = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                                    severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate  = if_abap_behv=>mk-on
                        %element-EndDate    = if_abap_behv=>mk-on
                      ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
