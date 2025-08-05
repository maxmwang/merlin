open Merlin_analysis.Overrides_interval_tree

let test_construct_1 =
  let open Alcotest in
  test_case "test basic list construction" `Quick (fun () ->
      let lst =
        [ ((0, 1), "1");
          ((0, 3), "2");
          ((2, 3), "3");
          ((0, 4), "4");
          ((0, 10), "5");
          ((5, 10), "6");
          ((5, 7), "7");
          ((8, 10), "8")
        ]
      in
      let tree = Result.get_ok (Interval_tree.of_alist lst) in
      let expected = [ "3"; "2"; "4"; "5" ] in
      let payloads = Interval_tree.find tree 2 in
      check (list string) "should be equal" expected payloads)

let cases = ("overrides-interval-tree", [ test_construct_1 ])
