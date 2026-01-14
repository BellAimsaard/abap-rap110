CLASS zrap110_calc_trav_elem_004 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS calculate_trav_status_ind
      IMPORTING
        is_original_data TYPE zrap110_c_traveltp_004
      RETURNING
        VALUE(rs_result) TYPE zrap110_c_traveltp_004.
ENDCLASS.



CLASS zrap110_calc_trav_elem_004 IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    "The method IF_SADL_EXIT_CALC_ELEMENT_READ~GET_CALCULATION_INFO provides a list of all elements
    "that are required for calculating the values of the virtual elements in the requested entity.
    "This method is called during runtime before the retrieval of data from the database to ensure
    "that all necessary elements for calculation are filled with data.

    CHECK: iv_entity EQ 'ZRAP110_C_TRAVELTP_004'. "Travel BO node

    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_travel_calc_element>).
      CASE <fs_travel_calc_element>.
        WHEN 'OVERALLSTATUSINDICATOR'.
          APPEND 'OVERALLSTATUS' TO et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~calculate.
    "The method IF_SADL_EXIT_CALC_ELEMENT_READ~CALCULATE executes the value calculation for the virtual element.
    "This method is called during runtime after data is retrieved from the database. The elements needed for the
    "calculation of the virtual elements are already inside the data table passed to this method. The method returns
    "a table that contains the values of the requested virtual elements.

    DATA lt_trav_original_data TYPE STANDARD TABLE OF ZRAP110_C_TravelTP_004 WITH DEFAULT KEY.

    IF it_requested_calc_elements IS INITIAL.
      EXIT.
    ENDIF.

    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_req_calc_elements>).
      CASE <fs_req_calc_elements>.
          "virtual elements from TRAVEL entity
        WHEN 'OVERALLSTATUSINDICATOR'.
          lt_trav_original_data = CORRESPONDING #( it_original_data ).
          LOOP AT lt_trav_original_data ASSIGNING FIELD-SYMBOL(<fs_trav_original_data>).

            <fs_trav_original_data> = zrap110_calc_trav_elem_004=>calculate_trav_status_ind( <fs_trav_original_data> ).

          ENDLOOP.
          ct_calculated_data = CORRESPONDING #( lt_trav_original_data ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculate_trav_status_ind.
    rs_result = CORRESPONDING #( is_original_data ).

    "travel status indicator
    "(criticality: 1  = red | 2 = orange  | 3 = green)
    CASE rs_result-OverallStatus.
      WHEN 'X'.
        rs_result-OverallStatusIndicator = 1.
      WHEN 'O'.
        rs_result-OverallStatusIndicator = 2.
      WHEN 'A'.
        rs_result-OverallStatusIndicator = 3.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
