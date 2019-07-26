(* ========================================================================= *)
(* FILE          : mleSynthesize.sml                                         *)
(* DESCRIPTION   : Specification of a term synthesis game                    *)
(* AUTHOR        : (c) Thibault Gauthier, Czech Technical University         *)
(* DATE          : 2019                                                      *)
(* ========================================================================= *)

structure mleSynthesize :> mleSynthesize =
struct

open HolKernel Abbrev boolLib aiLib smlParallel psMCTS psTermGen
  mlTreeNeuralNetwork mlTacticData mlReinforce mleLib mleArithData

val ERR = mk_HOL_ERR "mleSynthesize"

(* -------------------------------------------------------------------------
   Board
   ------------------------------------------------------------------------- *)

type board = ((term * int) * term)

val active_var = ``active_var:num``;

fun mk_startsit tm = ((tm,mleArithData.eval_numtm tm),active_var)
fun dest_startsit ((tm,_),_) = tm

fun is_ground tm = not (tmem active_var (free_vars_lr tm))

val synt_operl = [(active_var,0)] @ operl_of ``SUC 0 + 0 = 0 * 0``
fun nntm_of_sit ((ctm,_),tm) = mk_eq (ctm,tm)

fun status_of ((ctm,n),tm) =
  let val ntm = mk_sucn n in
    if term_eq ntm tm then Win
    else if is_ground tm orelse term_size tm > 2 * n + 1 then Lose
    else Undecided
  end

(* -------------------------------------------------------------------------
   Move
   ------------------------------------------------------------------------- *)

type move = (term * int)
val movel = operl_of ``SUC 0 + 0 * 0``;
val move_compare = cpl_compare Term.compare Int.compare

fun action_oper (oper,n) tm =
  let
    val res = list_mk_comb (oper, List.tabulate (n, fn _ => active_var))
    val sub = [{redex = active_var, residue = res}]
  in
    subst_occs [[1]] sub tm
  end

fun apply_move move (ctmn,tm) = (ctmn, action_oper move tm)

fun filter_sit sit = (fn l => l)

fun string_of_move (tm,_) = tts tm

fun write_targetl file targetl =
  let val tml = map dest_startsit targetl in
    export_terml (file ^ "_targetl") tml
  end

fun read_targetl file =
  let val tml = import_terml (file ^ "_targetl") in
    map mk_startsit tml
  end

fun max_bigsteps target = 2 * term_size (dest_startsit target) + 1

(* -------------------------------------------------------------------------
   Level
   ------------------------------------------------------------------------- *)

fun create_train_evalsorted () =
  let
    val filein = dataarith_dir ^ "/train"
    val fileout = dataarith_dir ^ "/train_evalsorted"
    val l1 = import_terml filein ;
    val l2 = map (fn x => (x, eval_numtm x)) l1
    val l3 = filter (fn x => snd x <= 100) l2
    val l4 = dict_sort compare_imin l3
  in
    export_terml fileout (map fst l4)
  end

fun mk_targetl level ntarget =
  let
    val tml = mlTacticData.import_terml (dataarith_dir ^ "/train_evalsorted")
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
  status_of = status_of,
  filter_sit = filter_sit,
  apply_move = apply_move,
  operl = synt_operl,
  nntm_of_sit = nntm_of_sit,
  mk_targetl = mk_targetl,
  write_targetl = write_targetl,
  read_targetl = read_targetl,
  string_of_move = string_of_move,
  max_bigsteps = max_bigsteps
  }

type dhex = (term * real list * real list) list
type dhtnn = mlTreeNeuralNetwork.dhtnn
type flags = bool * bool * bool

val extspec : (flags * dhtnn, board, bool * dhex) 
  smlParallel.extspec = mk_extspec "mleSynthesize.extspec" gamespec

(* -------------------------------------------------------------------------
   Statistics
   ------------------------------------------------------------------------- *)

fun maxeval_atgen () =
  let
    val tml = mlTacticData.import_terml (dataarith_dir ^ "/train_evalsorted")
  in
    map (list_imax o map eval_numtm) (mk_batch 400 tml)
  end

fun stats_eval file =
  let
    val l0 = import_terml file
    val l1 = map (fn x => (x,eval_numtm x)) l0;
    val l1' = filter (fn x => snd x <= 100) l1;
    val _  = print_endline (its (length l1'));
    val l2 = dlist (dregroup Int.compare (map swap l1'));
  in
    map_snd length l2
  end

end (* struct *)