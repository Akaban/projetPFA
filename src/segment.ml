(* Projet PFA 2015-2016
 * Université Paris Sud L3
 * Par Bryce Tichit *)
open Point

type tpos = L | R | C

type t = { id : int ;
          porig : Point.t; 
          pdest : Point.t;
          ci : float;
          ce : float;
          segBottom : t option;
          segRight : t option;
          segTop : t option;
          segLeft : t option;
          sens : tpos;
          couleur : Graphics.color option;
         }

let updateColor s c = {s with couleur=Some c}

let compteur x = let cpt = ref x in fun () -> cpt := !cpt + 1 ; !cpt;;
let idCount = ref (compteur 0);;

let resetIdCount () = idCount := compteur 0
let setCompteur x = idCount := compteur x
let getCurrentCount () = let cnt = !idCount () in
                         setCompteur (cnt-1) ; cnt-1


let fromSome default = function
  | Some s -> s
  | _ -> default

let originVector s = (s.pdest.x - s.porig.x,s.pdest.y - s.porig.y)
let sens s = 
  let (_,poy) = originVector s in 
  if poy >= 0 then R else L


let tposToString = function
  | L -> "Left"
  | R -> "Right"
  | C -> "Center"

let tangle s = (*tangente de l'angle du segment*)
  let a = float_of_int (s.pdest.y - s.porig.y)
  in let b = float_of_int (s.pdest.x - s.porig.x)
  in a /. b

let tangleTuple (xo,yo,xd,yd) =
  let a = yd -. yo in
  let b = xd -. xo in
  a /. b

let angle s = (*angle du segment*)
 Trigo.datan (tangle s)

let angleWithPoint p1 p2 =
  let a = float_of_int (p2.y - p1.y)
  in let b = float_of_int (p2.x - p1.x)
  in Trigo.datan (a/. b)


(*Prends un segment et rends ce segment sous forme de string*)
let toString s = Printf.sprintf "{id=%d;porig=%s;pdest=%s;ci=%f;ce=%f;angle=%d}" s.id (toString s.porig) (toString s.pdest) s.ci s.ce (truncate (angle s)) 

let to_f = float_of_int
let to_i = int_of_float

let new_segmentPointSimple p1 p2 = { id=(-1) ; porig=p1 ; pdest=p2 ; ci = 0.0 ; ce = 1.0 ; segBottom = None
                            ; segRight = None ; segTop = None ; segLeft = None; sens=C;couleur=None}

let sgn x = if x < 0 then -1 else 1

(*creation d'un segment selon deux points porig et pdest
 * creation de la zone rectangulaire de collision autour de ce segment
 * 4 segments définissant la zone de collision
 * on définit également le sens du segment *)
let new_segmentPoint p1 p2 = let idc = !idCount () in
                             let angle1 = truncate (angleWithPoint p1 p2) in
                             let angle = if angle1 = 0 then 90 else 180 - angle1 mod 90 in
                             let sizeCol = (!Options.wall_collision_size,0.) in
                             let bottomRight = translatePoint p1 (translateVect sizeCol angle)
                             in let bottomLeft = translatePoint p1 (translateVect sizeCol (angle+180)) in
                             let topRight = translatePoint p2 (translateVect sizeCol angle) in
                             let topLeft = translatePoint p2 (translateVect sizeCol (angle+180)) 
                             in let s = { id=idc ; porig=p1 ; pdest=p2 ; ci = 0.0 ; ce = 1.0; 
                                segBottom = Some (new_segmentPointSimple bottomLeft bottomRight);
                                segLeft = Some (new_segmentPointSimple bottomLeft topLeft);
                                segTop = Some (new_segmentPointSimple topLeft topRight);
                                segRight = Some (new_segmentPointSimple bottomRight topRight) ; sens=C;couleur=None }
                             in { s with sens=sens s}




let rotateSegmentOrig s angle = {s with pdest=translatePointWithAngle s.pdest (0.,0.) angle}

let new_segment xo yo xd yd = new_segmentPoint (new_point xo yo) (new_point xd yd) 
let new_segmentSimple xo yo xd yd = new_segmentPointSimple (new_point xo yo) (new_point xd yd)

let new_segmentSimpleFloat xo yo xd yd =
  let fxo, fyo, fxd, fyd = floor xo, floor yo, ceil xd, ceil yd in
  let ly = fyd -. fyo in
  let lx = fxd -. fxo in
  let ci, ce = if yo <> yd then 
    (yo -. fyo) /. ly, (yd -. fyo) /. ly else
    (xo -. fxo) /. lx, (xd -. fxo) /. ly in
  let seg = new_segmentSimple (truncate fxo) (truncate fyo) (truncate fxd) (truncate fyd) in
  { seg with ce=ce; ci=ci}
let new_segmentSimpleFloatWithid xo yo xd yd id =
  let seg = new_segmentSimpleFloat xo yo xd yd in
  { seg with id=id }

(* notre implémentation de segment utilise les pourcentage de début et de fin ci et ce
 * cette fonction renvoie les coordonnées réelles de notre segment*)
let real_coord s =
  let lx = s.pdest.x - s.porig.x
  in let ly = s.pdest.y - s.porig.y
  in let (xo,yo) = ( float_of_int s.porig.x +. (float_of_int lx) *. s.ci, float_of_int s.porig.y +. (float_of_int ly) *. s.ci)
  in let (xd,yd) = ( float_of_int s.porig.x +. (float_of_int lx) *. s.ce, float_of_int s.porig.y +. (float_of_int ly) *. s.ce)
  in (xo,yo),(xd,yd)

let real_coordInt s =
  let (xo,yo),(xd,yd) = real_coord s in
  (truncate xo,truncate yo),(truncate xd,truncate yd)

let norme s = 
  let (xo,yo),(xd,yd) = real_coord s in
  truncate (sqrt ((xd -. xo) ** 2. +. (yd-.yo) ** 2.))

 (* renvoie le point situé en bas à droite (en haut a gauche selon le sens )
 * de la zone de collision *)
let bottomRight s = match s.segRight with
  | Some s -> let (x,y),_ = real_coord s in new_point (truncate x) (truncate y)
  | None -> raise Not_found

(*coefficient z du sujet pour un point et un segment*)
let get_z p s = (s.pdest.x - s.porig.x) * (p.y - s.porig.y) - (s.pdest.y - s.porig.y) * (p.x - s.porig.x) 

(*par convention si un point est sur un segment on dira qu'il est a droite*)
let get_position p s =
     let z = get_z p s
     in if z > 0 then L
     else R;;

let get_position_s p s =
  let pos = get_position p s in
  tposToString pos

(*Prends une droite et un segment et renvoie les coordonnées d'interception de ces derniers
 * sinon renvoie None*)
let coordInterception d s =
    let (osx,osy) = originVector s
    in let (odx,ody) = originVector d
    in if osx=0 && odx=0 then None
    else let cd = (d.pdest.x - d.porig.x) * (s.pdest.y - s.porig.y) - (d.pdest.y - 
                 d.porig.y) * (s.pdest.x - s.porig.x)
         in if cd=0 then None else
         let cs = float_of_int ((d.porig.y - s.porig.y) * (d.pdest.x - d.porig.x) - (d.porig.x
                      - s.porig.x) * (d.pdest.y - d.porig.y)) /. (float_of_int cd)
         in if cs >= s.ce || cs < s.ci then None
               else Some cs;; 

     
let split_segment d s fid =
   match (coordInterception d s) with
    | None -> begin match (get_position s.porig d) with
                | L -> (Some s,None)
                | _ -> (None,Some s)
              end
    | Some p -> if p=0. then begin
                match (get_position s.pdest d) with
                  | L -> (Some s,None)
                  | _ -> (None,Some s)
                  end else
                let s1 = {s with ce = p;
                                id = fid ()}
                in let s2 = {s with ci=p;
                                id = fid ()}
                in let (s1xo,s1yo),(s1xd,s1yd) = real_coordInt s1 in
                let (s2xo,s2yo),(s2xd,s2yd) = real_coordInt s2 in
                let ts1 = new_segment s1xo s1yo s1xd s1yd (*on utilise new_segment pour calculer les deux nouvelles zones*)
                in let ts2 = new_segment s2xo s2yo s2xd s2yd (*de collision que l'on obtient*)
                in let (rs1,rs2) = { ts1 with ce=p ; id=ts1.id ; porig=s1.porig ; pdest = s1.pdest;couleur=s1.couleur}, { ts2 with ci=p ; id=ts2.id ;
                   porig=s2.porig; pdest=s2.pdest;couleur=s2.couleur}
                in begin match (get_position s.porig d) with
                         | L -> (Some rs1,Some rs2)
                         | _ -> (Some rs2,Some rs1)
                   end;;
   
(* split avec la fonction d'id fid *)
let splitId hd r fid =
  let rec split_do rest (l,r) = 
    match rest with
      | (t::ts) -> begin
            match (split_segment hd t fid) with
             | (Some s,None) -> split_do ts (s::l,r)
             | (None,Some s) -> split_do ts (l,s::r)
             | (Some s1,Some s2) -> split_do ts (s1::l,s2::r)
             | (None,None) -> assert false
             end
      | [] -> (l,r)
   in split_do r ([],[]);;

let split hd r = splitId hd r (!idCount)
let splitWithoutId hd r = splitId hd r (fun () -> (-1))
 
