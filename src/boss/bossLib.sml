(*---------------------------------------------------------------------------*
 * The "boss" library. This provides a collection of proof routines.         *
 * They provide                                                              *
 *                                                                           *
 *    1. Automatic maintenance of the usual products of a datatype           *
 *       definition.                                                         *
 *                                                                           *
 *    2. Some tools that work using that information.                        *
 *                                                                           *
 *    3. Some basic automation support.                                      *
 *                                                                           *
 *---------------------------------------------------------------------------*)

structure bossLib :> bossLib =
struct

open HolKernel Parse boolLib pairLib simpLib;

(* This makes the dependency on listTheory and optionTheory explicit.
   Without it, the theories can change, and bossLib won't get recompiled.
   This is because the listSimps and optionSimps signatures do not change
   in the event of listTheory and optionTheory changing. *)

local open listTheory optionTheory
           combinSyntax listSyntax optionSyntax numSyntax oneSyntax sumSyntax
           EvalRef Lift Drop
in end;

val ERR = mk_HOL_ERR "bossLib";

(*---------------------------------------------------------------------------*
            Datatype definition
 *---------------------------------------------------------------------------*)

fun type_rws tyn = #rewrs (TypeBase.simpls_of tyn)

val Hol_datatype = Datatype.Hol_datatype;


(*---------------------------------------------------------------------------
            Function definition
 ---------------------------------------------------------------------------*)

val xDefine    = TotalDefn.xDefine
val Define     = TotalDefn.Define
val Hol_defn   = Defn.Hol_defn;
val Hol_reln   = IndDefLib.Hol_reln;
val WF_REL_TAC = TotalDefn.WF_REL_TAC;


(*---------------------------------------------------------------------------
            Automated proof operations
 ---------------------------------------------------------------------------*)

val PROVE          = BasicProvers.PROVE
val PROVE_TAC      = BasicProvers.PROVE_TAC
val RW_TAC         = BasicProvers.RW_TAC
val SRW_TAC        = BasicProvers.SRW_TAC
val srw_ss         = BasicProvers.srw_ss
val augment_srw_ss = BasicProvers.augment_srw_ss

val EVAL           = computeLib.EVAL_CONV;
val EVAL_RULE      = computeLib.EVAL_RULE
val EVAL_TAC       = computeLib.EVAL_TAC

val op && = simpLib.&&;

(*---------------------------------------------------------------------------
     The following simplification sets will be applied in a context
     that extends that loaded by bossLib. They are intended to be used
     by RW_TAC. The choice of which simpset to use depends on factors
     such as running time.  For example, RW_TAC with arith_ss (and thus
     with list_ss) may take a long time on some goals featuring arithmetic
     terms (since the arithmetic decision procedure may be invoked). In
     such cases, it may be worth dropping down to use std_ss,
     supplying whatever arithmetic theorems are required, so that
     simplification is quick.
 ---------------------------------------------------------------------------*)

local open sumTheory
      infix ++
in
val pure_ss = pureSimps.pure_ss
val bool_ss = boolSimps.bool_ss
val std_ss =
     (boolSimps.bool_ss ++ pairSimps.PAIR_ss ++ optionSimps.OPTION_ss ++
      numSimps.REDUCE_ss ++ sumSimps.SUM_ss ++ combinSimps.COMBIN_ss)

val arith_ss = std_ss ++ numSimps.ARITH_ss
val list_ss  = arith_ss ++ listSimps.LIST_ss
val ARITH_ss = numSimps.ARITH_ss

end

fun DECIDE tm =
 numLib.ARITH_PROVE tm handle HOL_ERR _ => tautLib.TAUT_PROVE tm
                       handle HOL_ERR _ => raise ERR "DECIDE" "";


fun DECIDE_TAC (g as (asl,_)) =
((MAP_EVERY UNDISCH_TAC (filter numSimps.is_arith_asm asl)
      THEN numLib.ARITH_TAC)
 ORELSE
 tautLib.TAUT_TAC
 ORELSE
 NO_TAC) g;

fun ZAP_TAC ss thl =
   BasicProvers.STP_TAC ss
      (tautLib.TAUT_TAC
          ORELSE DECIDE_TAC
          ORELSE BasicProvers.GEN_PROVE_TAC 0 12 1 thl);


(*---------------------------------------------------------------------------
            Single step interactive proof operations
 ---------------------------------------------------------------------------*)


val Cases     = SingleStep.Cases
val Induct    = SingleStep.Induct
val recInduct = SingleStep.recInduct

val Cases_on          = SingleStep.Cases_on
val Induct_on         = SingleStep.Induct_on
val completeInduct_on = SingleStep.completeInduct_on
val measureInduct_on  = SingleStep.measureInduct_on;

val SPOSE_NOT_THEN    = SingleStep.SPOSE_NOT_THEN

val op by             = SingleStep.by; (* infix 8 by *)

val CASE_TAC          = SingleStep.CASE_TAC;

end
