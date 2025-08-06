module Interval = struct
  type 'a t = { low : int; high : int; payload : 'a }

  let create ~low ~high ~payload =
    match low <= high with
    | true -> Ok { low; high; payload }
    | false -> Error "input low greater than high"

  let compare_low t1 t2 = Int.compare t1.low t2.low

  let compare_range t1 t2 = Int.compare (t1.high - t1.low) (t2.high - t2.low)

  let payload t = t.payload
end

(** The type representing an interval tree node.

    [center] is an approximation of the median of all intervals contained in the subtree [t].

    [left] is the subtree containing all intervals to the left of [center].

    [left] is the subtree containing all intervals to the right of [center].

    [intervals] is a list of all intervals that contain [center] *)
type 'a t =
  { center : int;
    left : 'a t option;
    right : 'a t option;
    intervals : 'a Interval.t list
  }

let empty = { center = -1; left = None; right = None; intervals = [] }

(** Implementation based off of
    {{:https://en.wikipedia.org/wiki/Interval_tree#With_a_point}}this description.  *)
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

let rec of_alist_helper (lst : _ Interval.t list) =
  match List.length lst with
  | 0 -> None
  | length ->
    let median =
      (* The middle of the range of the middle interval is a close approximation to the
         median. *)
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
          | _ ->
            raise (Invalid_argument "input interval has low greater than high"))
        lst ([], [], [])
    in
    let left = of_alist_helper to_left in
    let right = of_alist_helper to_right in
    let intervals = to_overlap in
    Some { center = median; left; right; intervals }

let of_alist lst =
  let sorted_lst = List.stable_sort Interval.compare_low lst in
  match of_alist_helper sorted_lst with
  | Some tree -> tree
  | None -> empty
