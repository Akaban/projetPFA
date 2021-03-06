(* Projet PFA 2015-2016
 * Université Paris Sud L3
 * Par Bryce Tichit *)
open Options
open Physic
open Point
open Segment

type t = {
  mutable pos : Point.t;
  mutable pa : int;
  mutable oldpos : Point.t;
  mutable crouch : bool;
  mutable holdRush : bool (*mode maintient sprint*)
}

let calculateAngleMinimap p pa =
let divPos = divPoint p scale in
  let rightAnglePos = translatePointWithAngle divPos (sizeAngleMiniMap,0.) (pa-angleMiniMap) in
  let leftAnglePos = translatePointWithAngle divPos (sizeAngleMiniMap,0.) (pa+angleMiniMap) in
  new_segmentPointSimple divPos rightAnglePos, new_segmentPointSimple divPos leftAnglePos


let new_player pos pa =
  { pos=pos;pa=pa;oldpos=pos;crouch=false;holdRush=false}    

type dir = Left | Right

let mymod n m =
  if n >=0 then n mod m
  else m - (-n mod m)

let rotate i d p = match d with
  | Left -> p.pa <- mymod (p.pa + i) 360 
  | Right -> p.pa <- mymod (p.pa - i) 360
 
let rec crouchPlayer p =
  if p.crouch then begin
      p.crouch <- false ; eye_h := eye_h_debout ;
      step_dist := step_dist_debout end
  else begin
    if p.holdRush then rushPlayer p;
    p.crouch <- true ; eye_h := eye_h_accroupi ;
    step_dist := step_dist_accroupi end

and rushPlayer p =
  if p.holdRush then begin
      p.holdRush <- false ;
      step_dist := step_dist_debout end
  else begin
    if p.crouch then crouchPlayer p ;
    p.holdRush <- true ; 
    step_dist := step_dist_rush end


type mv = MFwd | MBwd | MLeft | MRight

let tp (tpx,tpy,tpa) p bsp = match mode with
  | ThreeD -> let npos = new_point tpx tpy in
              begin match detect_collision npos bsp with
                    | Some s -> Printf.printf "Teleportation annule car il y a une collision avec %s\n"
                                (toString s) ; flush stdout
                    | None -> p.pos <- npos  ; p.pa <- tpa
              end ;
              

  | _ -> ()


let move d p bsp =
  let doMove () =
  match mode with
  | TwoD -> let step = truncate !step_dist in
            let dx, dy = 
              match d with
                  | MFwd -> 0 , step
                  | MBwd -> 0 , -step
                  | MLeft -> -step, 0
                  | MRight -> step, 0
            in let new_pos = new_point (p.pos.x + dx) (p.pos.y + dy)
            in begin match (detect_collision new_pos bsp) with
                | Some s -> if !debug then begin
                          match s.segTop with None -> () | Some segt -> begin 
                          print_string ("Collision detecte avec " ^ Segment.toString s ^ "\n"); 
                          flush stdout ; Printf.printf "Votre position par rapport au segTop est %s et par rapport au seg est %s\n" 
                          (Segment.get_position_s new_pos segt) (Segment.get_position_s new_pos s);
                          flush stdout
                          end end
                | None -> p.oldpos <- p.pos ; p.pos <- new_pos
            end
  | ThreeD -> let dx, dy =
                match d with 
                  | MLeft -> 0. , !step_dist
                  | MRight -> 0. , -.(!step_dist)
                  | MBwd -> -.(!step_dist), 0.
                  | MFwd -> !step_dist, 0.
               in let new_pos = translatePointWithAngle p.pos (dx,dy) p.pa
               in match (detect_collision new_pos bsp) with
                  | Some s -> ()
                  | None -> p.pos <- new_pos 
  in if !step_dist > step_dist_debout then (*division du déplacement si celui-ci est plus grand (mode sprint) pour éviter les bugs de collision*)
      let howM = !step_dist /. step_dist_debout in
      let fl,i = modf howM in
      let sdist = !step_dist in
      step_dist := step_dist_debout ;
      for i=0 to ((truncate i) -1) do doMove () done ;
      step_dist := fl ;
      doMove() ;
      step_dist := sdist
  else doMove()
