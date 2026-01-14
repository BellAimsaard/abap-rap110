CLASS zrap110_calc_book_elem_004 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS calculate_days_to_flight
      IMPORTING
        iv_element        TYPE string
      CHANGING
        VALUE(cs_booking) TYPE zrap110_c_bookingtp_004.
ENDCLASS.



CLASS zrap110_calc_book_elem_004 IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    CHECK iv_entity EQ 'ZRAP110_C_BOOKINGTP_004'. "Booking BO node
    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<ls_booking_calc_element>).
      CASE <ls_booking_calc_element>.
        WHEN 'INITIALDAYSTOFLIGHT'.
          "COLLECT `BOOKINGDATE` INTO et_requested_orig_elements.
          "COLLECT `FLIGHTDATE` INTO et_requested_orig_elements.
        WHEN 'REMAININGDAYSTOFLIGHT'.
          "COLLECT `FLIGHTDATE` INTO et_requested_orig_elements.
        WHEN 'DAYSTOFLIGHTINDICATOR'.
          "COLLECT `FLIGHTDATE` INTO et_requested_orig_elements.
        WHEN 'BOOKINGSTATUSINDICATOR'.
          "COLLECT `BOOKINGSTATUS` INTO et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_book_original_data TYPE STANDARD TABLE OF ZRAP110_C_BookingTP_004 WITH DEFAULT KEY.

    IF it_requested_calc_elements IS INITIAL.
      EXIT.
    ENDIF.

    lt_book_original_data = CORRESPONDING #( it_original_data ).

    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<lv_req_calc_elements>).
      CASE <lv_req_calc_elements>.
          "virtual elements from BOOKING entity
        WHEN 'INITIALDAYSTOFLIGHT'
            OR 'REMAININGDAYSTOFLIGHT'
            OR 'DAYSTOFLIGHTINDICATOR'
            OR 'BOOKINGSTATUSINDICATOR'.

          LOOP AT lt_book_original_data ASSIGNING FIELD-SYMBOL(<ls_book_original_data>).

            zrap110_calc_book_elem_004=>calculate_days_to_flight(
                EXPORTING
                   iv_element  = <lv_req_calc_elements>
                CHANGING
                   cs_booking  = <ls_book_original_data> ).

          ENDLOOP.

      ENDCASE.
    ENDLOOP.
    ct_calculated_data = CORRESPONDING #( lt_book_original_data ).
  ENDMETHOD.

  METHOD calculate_days_to_flight.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    CASE iv_element.
      WHEN 'INITIALDAYSTOFLIGHT'.
        "VE InitialDaysToFlight: initial days to flight
        DATA(lv_initial_days) = cs_booking-FlightDate - cs_booking-BookingDate.
        IF lv_initial_days > 0 AND lv_initial_days < 999.
          cs_booking-InitialDaysToFlight =  lv_initial_days.
        ELSE.
          cs_booking-InitialDaysToFlight = 0.
        ENDIF.

      WHEN 'REMAININGDAYSTOFLIGHT' OR
           'DAYSTOFLIGHTINDICATOR'.
        DATA(lv_remaining_days) = cs_booking-FlightDate - lv_today.
        "VE RemainingDaysToFlight: remaining days to flight
        IF iv_element = 'REMAININGDAYSTOFLIGHT'.
          IF lv_remaining_days < 0 OR lv_remaining_days > 999.
            cs_booking-RemainingDaysToFlight = 0.
          ELSE.
            cs_booking-RemainingDaysToFlight =  cs_booking-FlightDate - lv_today.
          ENDIF.
        ELSEIF iv_element = 'DAYSTOFLIGHTINDICATOR'.

          "VE DaysToFlightIndicator: remaining days to flight *indicator*
          "(dataPoint: 1 = red | 2 = orange | 3 = green | 4 = grey | 5 = blue)
          IF lv_remaining_days >= 6.
            cs_booking-DaysToFlightIndicator = 3.       "green
          ELSEIF lv_remaining_days <= 5 AND lv_remaining_days >= 3.
            cs_booking-DaysToFlightIndicator = 2.       "orange
          ELSEIF lv_remaining_days <= 2 AND lv_remaining_days >= 0.
            cs_booking-DaysToFlightIndicator = 1.       "red
          ELSE.
            cs_booking-DaysToFlightIndicator = 4.       "grey
          ENDIF.

        ENDIF.

      WHEN 'BOOKINGSTATUSINDICATOR'.
        "VE BookingStatusIndicator: booking status indicator
        "(criticality: 1  = red | 2 = orange  | 3 = green)
        CASE cs_booking-BookingStatus.
          WHEN 'X'.
            cs_booking-BookingStatusIndicator = 1.
          WHEN 'N'.
            cs_booking-BookingStatusIndicator = 2.
          WHEN 'B'.
            cs_booking-BookingStatusIndicator = 3.
          WHEN OTHERS.
        ENDCASE.
    ENDCASE.

  ENDMETHOD.

ENDCLASS.
