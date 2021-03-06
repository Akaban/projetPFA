(* Projet PFA 2015-2016
 * Université Paris Sud L3
 * Par Bryce Tichit *)
open Graphics
open Segment
open Trigo
open Player
open Point
open Options
open Colors
open Printf

exception NePasTraiter

let fill_background color =
  set_color color;
  fill_rect 0 0 win_w win_h;
  revert_color ()

let fill_ceiling color h =
  try
    set_color color ;
    fill_rect 0 h win_w (win_h-h);
    revert_color ()
  with Invalid_argument(_) -> printf "Tried to call fill_ceiling with 
  h=%d and failed" h 

(*crée les intructions mais attends un unit de plus pour les executer*)
let pendingDrawSegment seg color () =
  if Array.length seg <> 4 then () else
  set_color color; 
  draw_segments seg;
  revert_color ()
let pendingFillPoly poly color () = 
  set_color color;
  fill_poly poly;
  revert_color ()
(*execute les instructions d'une liste*)
let sequence = List.iter (fun s -> s ())

let drawSegment s =
  let (xo,yo),(xd,yd) = real_coordInt s in
  Graphics.draw_segments [|xo,yo,xd,yd|]

let drawSegmentScale scale s = drawSegment {s with porig={s.porig with x=s.porig.x/scale ; y=s.porig.y/scale};
                                                   pdest={s.pdest with x=s.pdest.x/scale ; y=s.pdest.y/scale}}

let rotateSegment rs p tupleRef =
  let (oxo,oyo),(oxd,oyd) = Segment.real_coord !rs in
  let px, py = float_of_int p.pos.x, float_of_int p.pos.y in
      let xo = (oxo -. px) *. dcos (-p.pa) -. (oyo -. py) *. dsin (-p.pa) in
      let yo = (oyo -. py) *. dcos (-p.pa) +. (oxo -. px) *. dsin (-p.pa) in
      let xd = (oxd -. px) *. dcos (-p.pa) -. (oyd -. py) *. dsin (-p.pa) in
      let yd = (oyd -. py) *. dcos (-p.pa) +. (oxd -. px) *. dsin (-p.pa) in
      tupleRef := xo, yo, xd, yd 

let parseFunction3d p contour fill drawList s =
  let ci0,ce1 = s.ci=0.,s.ce=1. in
  let (xo,yo), (xd,yd) = Segment.real_coord s in
  let tupleRef = ref (xo,yo,xd,yd) in
  let clipSegment rs p =
    let distance = distance p.pos (new_point (truncate xo) (truncate yo)) in 
    let xo,yo,xd,yd = !tupleRef in 
    if  xo <= 1. && xd <= 1. || distance > xmax  then raise NePasTraiter (*on clippe le segment*)
    else if xo <= 1. then tupleRef := 1., 
          (yo +. (1. -. xo) *. (tangleTuple !tupleRef)),
          xd ,yd
    else if xd <= 1. then tupleRef := xo, yo, 1., 
            (yd +. (1. -. xd) *. (tangleTuple !tupleRef)) in
  let projectionSegment s =
    let d_focale = (float_of_int win_w /. 2.) /. (dtan (fov / 2)) in
    let xo,yo,xd,yd = !tupleRef in
    let xo,xd = min xo max_dist, min xd max_dist in
    let win_w = float_of_int win_w in
    let nyo,nyd = (win_w /. 2.)  -. ((yo *. d_focale) /. xo), (win_w /. 2.)  -. ((yd *. d_focale) /. xd)  in
    if nyo < 0. && nyd < 0. || nyo > win_w && nyd > win_w then raise NePasTraiter
  else
    let win_h = float_of_int win_h in 
    let hsDiv = win_h /. 2. in
    let zc x = hsDiv +. (float_of_int (ceiling_h - !eye_h) *. d_focale) /. x in
    let zf x = hsDiv +. (float_of_int (floor_h - !eye_h) *. d_focale) /. x in
    let zco, zfo, zcd, zfd = zc xo, zf xo, zc xd, zf xd in (* calcul des zc et zf*)
    (*correction zc zf*)
    let du, dl = (zcd -. zco) /. (nyd -. nyo), (zfd -. zfo) /. (nyd -. nyo) in
    let nyo, zco, zfo = if nyo < 0. then 0., zco -. (nyo *. du), zfo -. (nyo *. dl)
    else if nyo > win_h then win_h, zco -. ((nyo -. win_h) *. du), zfo -. ((nyo -. win_h) *. dl)
    else nyo,zco,zfo in
    let nyd, zcd, zfd = if nyd < 0. then 0., zcd -. (nyd *. du), zfd -. (nyd *. dl)
    else if nyd > win_h then win_h, zcd -. ((nyd -. win_h) *. du), zfd -. ((nyd -. win_h) *. dl)
    else nyd,zcd,zfd in
    let nyo, zco, zfo, nyd, zcd, zfd = truncate nyo, truncate zco, truncate zfo, truncate nyd, truncate zcd, truncate zfd in
    if !Options.debug then begin
      Printf.printf "Segment nb %d, porig: (%d,%d) porigUp: (%d,%d) pdest: (%d,%d) pdestUp :(%d,%d)\n" s.id 
                nyo zco nyo zfo nyd zfd nyd zcd; flush stdout; 
    Printf.printf "             which has rotated coordinates porig=(%d,%d) pdest=(%d,%d)\n" 
    (truncate xo) (truncate yo) (truncate xd) (truncate yd) ; flush stdout ;
    end ;
  nyo, zco, zfo, nyd, zcd, zfd in

  let segment = ref s in
  try
    let () = rotateSegment segment p tupleRef ; clipSegment segment p in
    let nyo, zco, zfo, nyd, zcd, zfd = projectionSegment s in
    if fill then drawList := pendingFillPoly 
          [|nyo,zco; nyo, zfo ; nyd, zfd; nyd, zcd|] (fromSome Options.fill_color s.couleur) :: !drawList;
    if contour then begin
      let c=Options.contour_color in 
      let contours = List.map (fun s -> pendingDrawSegment s c)
      [(if ci0 then [|nyo, zco, nyo, zfo|] else [||]) (*on n'affiche ce segment que si ci=0, evite les doublons du au split*)
      ;[|nyo, zfo, nyd, zfd|];
      [|nyo, zco, nyd, zcd|];
      (if ce1 then [|nyd, zfd, nyd, zcd|] else [||])] in
      drawList := List.rev_append contours !drawList
      end 
    with NePasTraiter -> ()


let truncate4tuple (x,y,z,t) = truncate x, truncate y, truncate z, truncate t 


let display bsp p runData =
  let parseFunction2d = drawSegment in
  let parseMiniMap p s =
    let (xo,yo),(xd,yd) = Segment.real_coordInt s in
    let decal=30*scale in
    let distorigine = truncate (distance p (new_point xo yo)) in
    if distorigine > minimap_xmax
    then ()
    (*on restreint la minimap à sizeMiniMap*)
    else drawSegmentScale scale (new_segment (xo-p.x+decal) (yo-p.y) (xd-p.x+decal) (yd-p.y))
  in
  let not_zero x = if x <= 1 then 1 else x in
        match mode with
        | TwoD -> Bsp.parse parseFunction2d bsp (p.pos) ; set_color white ; fill_circle p.oldpos.x p.oldpos.y size2d ;
          set_color blue ; fill_circle p.pos.x p.pos.y size2d ; set_color black
        | ThreeD ->  let drawList = ref [] in
                     let ceilh = defaultCeilingh in
                     clear_graph () ; fill_background Options.bg ; 
                    Bsp.rev_parse (parseFunction3d p !Options.draw_contour !Options.fill_wall drawList) bsp (p.pos) ;
                    fill_ceiling Options.ceiling_color ceilh ;
                    sequence (List.rev !drawList); (*on dessine le tout sachant 
                                                   que nos instructions sont à l'envers 
                                                   donc on renverse*)
                    if !Options.debug then begin (*séparateur pour y voir plus clair dans le debug*)
                      Printf.printf "\n_____________________________________________________________\n" ; flush stdout end ;
                    if Options.minimap then begin
                    set_color Options.minimap_color ; Bsp.rev_parse (parseMiniMap p.pos) bsp (p.pos); revert_color () ; set_color red ;
                    fill_circle 0 0 (not_zero (size2d/scale)) ;
                    begin let pos = new_point 30 0 in (*sur la minimap c'est le labyrinthe qui se déplace et non le joueur*)
                    let l,r = translatePointWithAngle pos (sizeAngleMiniMap,0.) (p.pa-angleMiniMap),
                              translatePointWithAngle pos (sizeAngleMiniMap,0.) (p.pa+angleMiniMap) in
                    let sl,sr = new_segmentPointSimple pos l, new_segmentPointSimple pos r in  
                    drawSegment sl ; drawSegment sr end ;
                    revert_color ()
                    end;
                    if runData.playerInfo then begin
                      let cx, cy = current_x (), current_y () in
                      moveto (win_w - 120) 5 ;
                      set_color blue ;
                      draw_string (Printf.sprintf "(x=%d,y=%d,a=%d)" 
                                   p.pos.x p.pos.y p.pa);
                      moveto cx cy ; revert_color () end

(*On ne peut pas faire de sleep avec graphics,
 * la fonction suivante ne peut donc pas fonctionner*)
(*let fsleep = Thread.delay
*
let jumpAnimation bsp p runData =
  let origine,peak = !eye_h,!eye_h + jumpPeak in
  while !eye_h < peak do
    Unix.fsleep (1/jumpSpeed) ;
    eye_h := !eye_h + 1;
    display bsp p runData
  done;
  while !eye_h > origine do
    Unix.fsleep (1/gravity) ;
    eye_h := !eye_h - 1;
    display bsp p runData done;;                   
*)

let jumpAnimation bsp p runData = failwith "Not implemented"
