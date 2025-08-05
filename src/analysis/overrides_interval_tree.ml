module Interval_tree = struct
  module Interval = struct
    type 'a t = { low : int; high : int; payload : 'a }

    let create ~low ~high ~payload = { low; high; payload }

    let compare t1 t2 = Int.compare t1.low t2.low
  end

  type 'a t =
    { center : int;
      left : 'a t option;
      right : 'a t option;
      intervals_by_low : 'a Interval.t list;
      intervals_by_high : 'a Interval.t list
    }

  let rec construct (lst : _ Interval.t list) =
    match List.length lst with
    | 0 -> None
    | length ->
      let median =
        let median_interval = List.nth lst (length / 2) in
        (median_interval.low + median_interval.high) / 2
      in
      let to_left, to_overlap, to_right =
        List.fold_right
          (fun (interval : _ Interval.t) (to_left, to_overlap, to_right) ->
            match (interval.low <= median, interval.high < median) with
            | true, true -> (interval :: to_left, to_overlap, to_right)
            | true, false -> (to_left, interval :: to_overlap, to_right)
            | false, false -> (to_left, to_overlap, interval :: to_right)
            | _ -> (to_left, to_overlap, to_right))
          lst ([], [], [])
      in
      let left = construct to_left in
      let right = construct to_right in
      let intervals_by_low = to_overlap in
      let intervals_by_high = List.rev to_overlap in
      Some { center = median; left; right; intervals_by_low; intervals_by_high }

  let of_alist lst =
    let intervals =
      lst
      |> List.map (fun ((low, high), payload) ->
             Interval.create ~low ~high ~payload)
      |> List.stable_sort Interval.compare
    in
    match construct intervals with
    | Some tree -> Ok tree
    | None -> Error "input list has length 0"

  let rec find_helper t point =
    match point <= t.center with
    | true -> (
      let of_t =
        List.filter
          (fun (interval : _ Interval.t) -> interval.low <= point)
          t.intervals_by_low
      in
      match t.left with
      | Some left ->
        let of_left = find_helper left point in
        of_left @ of_t
      | None -> of_t)
    | false -> (
      let of_t =
        List.filter
          (fun (interval : _ Interval.t) -> interval.high >= point)
          t.intervals_by_high
      in
      match t.right with
      | Some right ->
        let of_right = find_helper right point in
        of_right @ of_t
      | None -> of_t)

  let find (t : _ t) point =
    find_helper t point
    |> List.sort (fun (interval1 : _ Interval.t) interval2 ->
           Int.compare
             (interval1.high - interval1.low)
             (interval2.high - interval2.low))
    |> List.map (fun (interval : _ Interval.t) -> interval.payload)
end
