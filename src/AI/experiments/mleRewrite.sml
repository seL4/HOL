(* ========================================================================= *)
(* FILE          : mleRewrite.sml                                            *)
(* DESCRIPTION   : Term rewriting as a reinforcement learning game           *)
(* AUTHOR        : (c) Thibault Gauthier, Czech Technical University         *)
(* DATE          : 2018                                                      *)
(* ========================================================================= *)

structure mleRewrite :> mleRewrite =
struct

open HolKernel boolLib Abbrev aiLib smlParallel psMCTS psTermGen
  mlTreeNeuralNetwork mlTacticData mlReinforce mleLib mleArithData

val ERR = mk_HOL_ERR "mleRewrite"

(* -------------------------------------------------------------------------
   Board
   ------------------------------------------------------------------------- *)

type pos = int list
type board = (term * pos)

fun mk_startsit tm = (tm,[])
fun dest_startsit (tm,_) = tm

fun status_of (tm,_) = if is_suc_only tm then Win else Undecided

(* -------------------------------------------------------------------------
   Neural network units and inputs
   ------------------------------------------------------------------------- *)

val numtag = mk_var ("numtag", ``:num -> num``)

fun tag_pos (tm,pos) =
  if null pos then (if is_eq tm then tm else mk_comb (numtag,tm)) else
  let
    val (oper,argl) = strip_comb tm
    fun f i arg = if i = hd pos then tag_pos (arg,tl pos) else arg
  in
    list_mk_comb (oper, mapi f argl)
  end

val rewrite_operl =
  let val operl' = (numtag,1) :: operl_of (``0 * SUC 0 + 0 = 0``) in
    mk_fast_set oper_compare operl'
  end

fun nntm_of_sit (tm,pos) = tag_pos (tm,pos)

(* -------------------------------------------------------------------------
   Move
   ------------------------------------------------------------------------- *)

datatype move = Arg of int | Paramod of (int * bool)

val movel =
  map Arg [0,1] @
  [Paramod (0,true),Paramod (0,false)] @
  [Paramod (1,true),Paramod (1,false)] @
  [Paramod (2,true)] @
  [Paramod (3,true),Paramod (3,false)]

fun move_compare (m1,m2) = case (m1,m2) of
    (Arg i1, Arg i2) => Int.compare (i1,i2)
  | (Arg _, _) => LESS
  | (_,Arg _) => GREATER
  | (Paramod (i1,b1), Paramod (i2,b2)) =>
    (cpl_compare Int.compare bool_compare) ((i1,b1),(i2,b2))

fun bts b = if b then "t" else "f"

fun string_of_move move = case move of
    Arg n => ("A" ^ its n)
  | Paramod (i,b) => ("P" ^ its i ^ bts b)

fun narg tm = length (snd (strip_comb tm))

fun argn_pb n (tm,pos) = (tm,pos @ [n])

fun paramod_pb (i,b) (tm,pos) =
  let
    val ax = Vector.sub (robinson_eq_vect,i)
    val tmo = paramod_ground (if b then ax else sym ax) (tm,pos)
  in
    (valOf tmo,[])
  end

fun available (tm,pos) (move,r:real) = case move of
    Arg i => (narg (find_subtm (tm,pos)) >= i + 1)
  | Paramod (i,b) => can (paramod_pb (i,b)) (tm,pos)

fun apply_move move (tm,pos) = case move of
    Arg n => argn_pb n (tm,pos)
  | Paramod (i,b) => paramod_pb (i,b) (tm,pos)

fun filter_sit (tm,pos) = List.filter (available (tm,pos))

(* -------------------------------------------------------------------------
   Target
   ------------------------------------------------------------------------- *)

fun lo_prooflength_target (tm,_) = lo_prooflength 200 tm

fun write_targetl file targetl =
  let val tml = map dest_startsit targetl in
    mlTacticData.export_terml (file ^ "_targetl") tml
  end

fun read_targetl file =
  let val tml = mlTacticData.import_terml (file ^ "_targetl") in
    map mk_startsit tml
  end

fun max_bigsteps target = 2 * lo_prooflength_target target + 1

(* -------------------------------------------------------------------------
   Level
   ------------------------------------------------------------------------- *)

fun create_train_evalsorted () =
  let
    val filein = dataarith_dir ^ "/train"
    val fileout = dataarith_dir ^ "/train_plsorted"
    val l1 = import_terml filein ;
    val l2 = mapfilter (fn x => (x, lo_prooflength 200 x)) l1
    val l3 = filter (fn x => snd x <= 100) l2
    val l4 = dict_sort compare_imin l3
  in
    export_terml fileout (map fst l4)
  end

fun mk_targetl level ntarget =
  let
    val tml = mlTacticData.import_terml (dataarith_dir ^ "/train_plsorted")
    val tmll = map shuffle (first_n level (mk_batch 400 tml))
    val tml2 = List.concat (list_combine tmll)
  in
    map mk_startsit (first_n ntarget tml2)
  end

(* -------------------------------------------------------------------------
   Interface
   ------------------------------------------------------------------------- *)

val gamespec : (board,move) mlReinforce.gamespec =
  {
  movel = movel,
  move_compare = move_compare,
  string_of_move = string_of_move,
  filter_sit = filter_sit,
  status_of = status_of,
  apply_move = apply_move,
  operl = rewrite_operl,
  nntm_of_sit = nntm_of_sit,
  mk_targetl = mk_targetl,
  write_targetl = write_targetl,
  read_targetl = read_targetl,
  max_bigsteps = max_bigsteps
  }

val extspec = mk_extspec "mleRewrite.extspec" gamespec

(* -------------------------------------------------------------------------
   Statistics
   ------------------------------------------------------------------------- *)

fun maxprooflength_atgen () =
  let val tml = import_terml (dataarith_dir ^ "/train_plsorted") in
    map (list_imax o map (lo_prooflength 200)) (mk_batch 400 tml)
  end

fun stats_prooflength file =
  let
    val l0 = import_terml file
    val l1 = mapfilter (fn x => (x,(lo_prooflength 200) x)) l0
    val _  = print_endline (its (length l1))
    val l2 = dlist (dregroup Int.compare (map swap l1))
  in
    map_snd length l2
  end

(* -------------------------------------------------------------------------
   Reinforcement learning
   ------------------------------------------------------------------------- *)

(*
load "mleRewrite"; open mleRewrite;
load "mlTreeNeuralNetwork"; open mlTreeNeuralNetwork;
load "mlReinforce"; open mlReinforce;
load "aiLib"; open aiLib;

logfile_glob := "mleRewrite_run40";
parallel_dir := HOLDIR ^ "/src/AI/sml_inspection/parallel_" ^
(!logfile_glob);
ncore_mcts_glob := 8;
ncore_train_glob := 4;
ntarget_compete := 400;
ntarget_explore := 400;
exwindow_glob := 40000;
uniqex_flag := false;
dim_glob := 12;
lr_glob := 0.02;
batchsize_glob := 16;
decay_glob := 0.99;
level_glob := 1;
nsim_glob := 1600;
nepoch_glob := 100;
ngen_glob := 20
start_rl_loop (gamespec,extspec);
*)

(* -------------------------------------------------------------------------
   Small test
   ------------------------------------------------------------------------- *)

(* 
load "mleRewrite"; open mleRewrite;
load "mlReinforce"; open mlReinforce;
load "psMCTS"; open psMCTS;
nsim_glob := 10000;
decay_glob := 0.9;
val _ = n_bigsteps_test gamespec (random_dhtnn_gamespec gamespec) 
(mk_startsit ``SUC 0 * SUC 0``);

dim_glob := 4;
val tree = mcts_test 10000 gamespec (random_dhtnn_gamespec gamespec) 
(mk_startsit ``SUC (SUC 0) + SUC 0``);
val nodel = trace_win (#status_of gamespec) tree [];

*)

end (* struct *)