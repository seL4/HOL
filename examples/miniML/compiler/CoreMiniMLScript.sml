(* generated by Lem from coreMiniML.lem *)
open bossLib Theory Parse res_quanTheory
open finite_mapTheory listTheory pairTheory pred_setTheory integerTheory
open set_relationTheory sortingTheory stringTheory wordsTheory

val _ = new_theory "CoreMiniML"

open MiniMLTheory

(* Intermediate language for MiniML compiler *)
(*open MiniML*)

val _ = Hol_datatype `
 Cprimop =
    CAdd | CSub | CMult | CDiv | CMod
  | CLt | CLeq | CEq | CIf | CAnd | COr`;


val _ = Hol_datatype `
 Cpat =
    CPvar of num
  | CPlit of lit
  | CPcon of num => Cpat list`;


val _ = Hol_datatype `
 Cexp =
    CRaise of error
  | CVar of num
  | CLit of lit
  | CCon of num => Cexp list
  | CProj of Cexp => num
  | CFun of num list => Cexp
  | CCall of Cexp => Cexp list
  | CPrimCall of Cprimop => Cexp list
  | CMat of Cexp => (Cpat # Cexp) list
  | CLet of (num # Cexp) list => Cexp
  | CFix of (num # num # Cexp) list => Cexp`;


(*val range : forall 'a 'b.  ('a,'b) Pmap.map -> 'b set*)
val _ = type_abbrev( "varmap" , ``: (string,num) Pmap $ map``);
(*val extend :  varmap -> string -> varmap * num*)
 val extend_aux_defn = Hol_defn "extend_aux" `

(extend_aux m vn n = if EXISTS  (\ n' . n = n') (SET_TO_LIST  (FRANGE m)) (* TODO: why no MEM? *)
then extend_aux m vn (n+1) else (FUPDATE  m ( vn, n), n))`;

val _ = Defn.save_defn extend_aux_defn;
val _ = Define `
 (extend m vn = extend_aux m vn 0)`;


 val pat_to_Cpat_defn = Hol_defn "pat_to_Cpat" `

(pat_to_Cpat (m, Pvar vn) =
  let (m',vn) = extend m vn in
  (m', CPvar vn))
/\
(pat_to_Cpat (m, Plit l) = (m, CPlit l))
/\
(pat_to_Cpat (m, Pcon cn ps) =
  let (m',ps) = FOLDL
    (\ (m,ps) p . let (m',p) = pat_to_Cpat (m,p) in (m',p::ps))
          (m,[]) ps in
  (m', CPcon (FAPPLY  m  cn) ps))`;

val _ = Defn.save_defn pat_to_Cpat_defn;

 val exp_to_Cexp_defn = Hol_defn "exp_to_Cexp" `

(exp_to_Cexp (m, Raise err) = (m, CRaise err))
/\
(exp_to_Cexp (m, Val (Lit l)) = (m, CLit l))
/\
(exp_to_Cexp (m, Con cn es) =
  (m, CCon (FAPPLY  m  cn) (MAP (\ e . let (_,e) = exp_to_Cexp (m,e) in e) es)))
/\
(exp_to_Cexp (m, Var vn) = (m, CVar (FAPPLY  m  vn)))
/\
(exp_to_Cexp (m, Fun vn e) =
  let (m',vn) = extend m vn in
  let (m',e) = exp_to_Cexp (m', e) in
  (m, CFun [vn] e))
/\
(exp_to_Cexp (m, App (Opn opn) e1 e2) =
  let (_,e1) = exp_to_Cexp (m, e1) in
  let (_,e2) = exp_to_Cexp (m, e2) in
  (m, CPrimCall ((case opn of
                   Plus   => CAdd
                 | Minus  => CSub
                 | Times  => CMult
                 | Divide => CDiv
                 | Modulo => CMod
                 ))
      [e1;e2]))
/\
(exp_to_Cexp (m, App (Opb Gt) e1 e2) =
  exp_to_Cexp (m, App (Opb Lt) e2 e1))
/\
(exp_to_Cexp (m, App (Opb Geq) e1 e2) =
  exp_to_Cexp (m, App (Opb Leq) e2 e1))
/\
(exp_to_Cexp (m, App (Opb opb) e1 e2) =
  let (_,e1) = exp_to_Cexp (m, e1) in
  let (_,e2) = exp_to_Cexp (m, e2) in
  (m, CPrimCall ((case opb of
                   Lt  => CLt
                 | Leq => CLeq
                 ))
      [e1;e2]))
/\
(exp_to_Cexp (m, Log log e1 e2) =
  let (_,e1) = exp_to_Cexp (m, e1) in
  let (_,e2) = exp_to_Cexp (m, e2) in
  (m, CPrimCall ((case log of
                   And => CAnd
                 | Or  => COr
                 ))
      [e1;e2]))
/\
(exp_to_Cexp (m, If e1 e2 e3) =
  let (_,e1) = exp_to_Cexp (m, e1) in
  let (_,e2) = exp_to_Cexp (m, e2) in
  let (_,e3) = exp_to_Cexp (m, e3) in
  (m, CPrimCall CIf [e1;e2;e3]))
/\
(exp_to_Cexp (m, Mat e pes) =
  let (_,e) = exp_to_Cexp (m, e) in
  let pes = FOLDL
    (\ pes (p,e) . let (m,p) = pat_to_Cpat (m,p) in
                      let (_,e) = exp_to_Cexp (m,e) in
                      (p,e)::pes)
         [] pes in
  (m, CMat e pes))
/\
(exp_to_Cexp (m, Let vn e b) =
  let (m',vn) = extend m vn in
  let (_,e) = exp_to_Cexp (m, e) in
  let (_,b) = exp_to_Cexp (m', b) in
  (m, CLet [(vn,e)] b))
/\
(exp_to_Cexp (m, Letrec defs b) =
  let (m',fns) = FOLDL
    (\ (m,fns) . \x . (case x of (d,_,_) => let (m',fn) = extend m d in (m',fn::fns)))
          (m,[]) defs in
  let defs = FOLDL
    (\ defs . \x . (case x of (fn,(_,vn,e)) =>
      let (m'',vn) = extend m' vn in
      let (_,e) = exp_to_Cexp (m'',e) in
      (fn,vn,e)::defs))
          [] (ZIP ( fns, defs)) in
  let (_,b) = exp_to_Cexp (m',b) in
  (m, CFix defs b))`;

val _ = Defn.save_defn exp_to_Cexp_defn;

(*

(* A simple ML-like language that does not remain convenient to program in, but
   is suitable for:
 1. translation from MiniML
 2. source to source optimization
 3. translation to bytecode *)

open MiniML

type labN = string

type Cprimop =
  | CAdd | CSub | CMult | CDiv | CMod
  | CLt | CGt | CLeq | CGeq | CEqNum
  | CEqCon | CAnd | COr

type Cexp =
  | CCall of Cexp * Catom
  | CClosure of labN * varN list
  | CCase of Cexp * Calts
  | CLet of varN * Cexp * Cexp
  | CPrimCall of Cprimop * varN * varN
  | CCon of num * varN list
  | CProj of varN * num
  | CRaise of error

and Catom =
  | CVar of varN
  | CLit of lit

and Calts =
  | Conalts of (num * varN list * Cexp) list * Dftalt
  | Litalts of (lit * Cexp) list * Dftalt
and Dftalt = CNoDft | CDft of varN * Cexp

(* wrap expressions with bindings of labels to functions.
   labels will eventually be mapped to codeptrs.
   varN list is free variables.
   may be better to have an environment instead (add CLetEnv, change CClosure)
   to make environment sharing easier?
   should allow multi-argument functions to be represented so they can be optimized? *)

type Ctopexp = Labels of (labN, (varN list * varN * Cexp)) env * Cexp

(* compilation assumptions:
 - all variable names distinct
 - declarations processed elsewhere to make an
   environment, available during compilation *)
*)
val _ = export_theory()
