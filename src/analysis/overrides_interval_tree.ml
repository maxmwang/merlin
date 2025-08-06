let input_low_greater_than_high = Invalid_argument "input low greater than high"

let input_invalid_interval_range =
  Invalid_argument "input interval ranges has low greater than high"

module Interval = struct
  type 'a t = { low : int; high : int; payload : 'a }

  let create ~low ~high ~payload =
    if low > high then raise input_low_greater_than_high
    else { low; high; payload }

  let compare_low t1 t2 = Int.compare t1.low t2.low

  let compare_range t1 t2 = Int.compare (t1.high - t1.low) (t2.high - t2.low)

  let payload t = t.payload
end

type 'a t =
  { center : int;
    left : 'a t option;
    right : 'a t option;
    intervals : 'a Interval.t list
  }

let rec find_helper t point =
  match point <= t.center with
  | true -> (
    let of_t =
      List.filter
        (fun (interval : _ Interval.t) -> interval.low <= point)
        t.intervals
    in
    match t.left with
    | Some left ->
      let of_left = find_helper left point in
      of_left @ of_t
    | None -> of_t)
  | false -> (
    let of_t =
      List.filter
        (fun (interval : _ Interval.t) -> interval.high > point)
        t.intervals
    in
    match t.right with
    | Some right ->
      let of_right = find_helper right point in
      of_right @ of_t
    | None -> of_t)

let find t point =
  let intervals =
    find_helper t point
    |> List.sort Interval.compare_range
    |> List.map Interval.payload
  in
  match intervals with
  | [] -> None
  | first :: _ -> Some first

let rec of_alist_helper (lst : _ Interval.t array) =
  match Array.length lst with
  | 0 -> None
  | length ->
    (* The middle of the range of the middle interval is a close approximation to the
       median. *)
    let median =
      let median_interval = Array.get lst (length / 2) in
      (median_interval.low + median_interval.high) / 2
    in
    (* A two-pass, out-of-place, stable partition. A stable partition is desired such that
       medians can be easily calculated in recursive calls *)
    let target = Array.copy lst in
    let left_count, overlap_count =
      Array.fold_left
        (fun (left_count, overlap_count) (interval : _ Interval.t) ->
          match (interval.low <= median, interval.high < median) with
          | true, true -> (left_count + 1, overlap_count)
          | true, false -> (left_count, overlap_count + 1)
          | false, false -> (left_count, overlap_count)
          | _ -> raise input_invalid_interval_range)
        (0, 0) lst
    in
    let right_count = length - left_count - overlap_count in
    let left_i, overlap_i, right_i =
      (ref 0, ref left_count, ref (left_count + overlap_count))
    in
    Array.iter
      (fun (interval : _ Interval.t) ->
        match (interval.low <= median, interval.high < median) with
        | true, true ->
          Array.set target !left_i interval;
          left_i := !left_i + 1
        | true, false ->
          Array.set target !overlap_i interval;
          overlap_i := !overlap_i + 1
        | false, false ->
          Array.set target !right_i interval;
          right_i := !right_i + 1
        | _ -> raise input_invalid_interval_range)
      lst;
    let left = of_alist_helper (Array.sub target 0 left_count) in
    let right =
      of_alist_helper
        (Array.sub target (left_count + overlap_count) right_count)
    in
    let intervals = Array.to_list (Array.sub target left_count overlap_count) in
    Some { center = median; left; right; intervals }

let of_alist_exn lst =
  let intervals = Array.of_list lst in
  Array.stable_sort Interval.compare_low intervals;
  match of_alist_helper intervals with
  | Some tree -> tree
  | None -> raise (Invalid_argument "input list is empty")
