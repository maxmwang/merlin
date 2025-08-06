open Merlin_analysis

let create_intervals intervals =
  intervals
  |> List.map (fun ((low, high), payload) ->
         Overrides_interval_tree.Interval.create ~low ~high ~payload)
  |> Overrides_interval_tree.of_alist_exn

let test_construct =
  let open Alcotest in
  test_case "test basic list construction" `Quick (fun () ->
      let _ : string Overrides_interval_tree.t =
        create_intervals
          [ ((0, 1), "1");
            ((0, 3), "2");
            ((2, 3), "3");
            ((0, 4), "4");
            ((0, 10), "5");
            ((5, 10), "6");
            ((5, 7), "7");
            ((8, 10), "8");
            ((0, 2), "9");
            ((2, 2), "10")
          ]
      in
      ())

let test_construct_no_total_order_actual =
  let open Alcotest in
  test_case "test construction of intervals without total ordering actual"
    `Quick (fun () ->
      check_raises "should raise exn"
        (Invalid_argument "input low greater than high") (fun () ->
          let _ =
            create_intervals [ ((0, 3), "1"); ((1, 4), "2"); ((5, 0), "3") ]
          in
          ()))

let test_find ~input ~expected =
  (*
    0 1 2 3 4 5 6 7 8 9 10
    ----------5---------
    ----4---  -----6----
    ---2--    --7-  --8-
    -1  -3            -9
        0
   *)
  let tree =
    create_intervals
      [ ((0, 1), "1");
        ((0, 3), "2");
        ((2, 3), "3");
        ((0, 4), "4");
        ((0, 10), "5");
        ((5, 10), "6");
        ((5, 7), "7");
        ((8, 10), "8");
        ((9, 10), "9");
        ((2, 2), "0")
      ]
  in
  let open Alcotest in
  test_case
    ("test find on input " ^ Int.to_string input)
    `Quick
    (fun () ->
      let payload = Overrides_interval_tree.find tree input in
      check (option string) "should be equal" expected payload)

let test_find_first =
  let tree = create_intervals [ ((0, 4), "0"); ((2, 2), "1"); ((2, 2), "2") ] in
  let open Alcotest in
  test_case "test find on input with duplicate intervals" `Quick (fun () ->
      let expected = Some "1" in
      let payload = Overrides_interval_tree.find tree 2 in
      check (option string) "should be equal" expected payload)

let cases =
  ( "overrides-interval-tree",
    [ test_construct;
      (*= test_construct_no_total_order; *)
      test_construct_no_total_order_actual;
      test_find ~input:0 ~expected:(Some "1");
      test_find ~input:1 ~expected:(Some "2");
      test_find ~input:2 ~expected:(Some "0");
      test_find ~input:3 ~expected:(Some "4");
      test_find ~input:4 ~expected:(Some "5");
      test_find ~input:5 ~expected:(Some "7");
      test_find ~input:6 ~expected:(Some "7");
      test_find ~input:7 ~expected:(Some "6");
      test_find ~input:8 ~expected:(Some "8");
      test_find ~input:9 ~expected:(Some "9");
      test_find ~input:10 ~expected:None;
      test_find_first
    ] )
