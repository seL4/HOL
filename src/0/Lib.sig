(* ===================================================================== *)
(* FILE          : lib.sig                                               *)
(* DESCRIPTION   : Signature for library of useful SML functions.        *)
(*                                                                       *)
(* AUTHOR        : (c) Konrad Slind, University of Calgary               *)
(* DATE          : August 26, 1991                                       *)
(* Modified      : September 22, 1997, Ken Larsen                        *)
(* ===================================================================== *)


signature Lib =
sig
  val curry : ('a * 'b -> 'c) -> 'a -> 'b -> 'c
  val uncurry : ('a -> 'b -> 'c) -> 'a * 'b -> 'c
  val append : 'a list -> 'a list -> 'a list
  val concat : string -> string -> string
  val equal : ''a -> ''a -> bool
  val cons : 'a -> 'a list -> 'a list
  val ## : ('a -> 'b) * ('c -> 'd) -> 'a * 'c -> 'b * 'd
  val A : ('a -> 'b) -> 'a -> 'b
  val B : ('a -> 'b) -> ('c -> 'a) -> 'c -> 'b
  val C : ('a -> 'b -> 'c) -> 'b -> 'a -> 'c
  val I : 'a -> 'a
  val K : 'a -> 'b -> 'a
  val S : ('a -> 'b -> 'c) -> ('a -> 'b) -> 'a -> 'c
  val W : ('a -> 'a -> 'b) -> 'a -> 'b
  val fst : 'a * 'b -> 'a
  val snd : 'a * 'b -> 'b
  val can : ('a -> 'b) -> 'a -> bool
  val try : ('a -> 'b) -> 'a -> 'b
  val trye : ('a -> 'b) -> 'a -> 'b
  val assert : ('a -> bool) -> 'a -> 'a
  val tryfind : ('a -> 'b) -> 'a list -> 'b
  val el : int -> 'a list -> 'a
  val index : ''a -> ''a list -> int
  val map2 : ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list
  val all : ('a -> bool) -> 'a list -> bool
  val all2 : ('a -> 'b -> bool) -> 'a list -> 'b list -> bool
  val exists : ('a -> bool) -> 'a list -> bool
  val first : ('a -> bool) -> 'a list -> 'a
  val split_after : int -> 'a list -> 'a list * 'a list
  val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
  val gather : ('a -> bool) -> 'a list -> 'a list
  val filter : ('a -> bool) -> 'a list -> 'a list
  val itlist : ('a -> 'b -> 'b) -> 'a list -> 'b -> 'b
  val itlist2 :('a -> 'b -> 'c -> 'c) -> 'a list -> 'b list -> 'c -> 'c
  val rev_itlist : ('a -> 'b -> 'b) -> 'a list -> 'b -> 'b
  val rev_itlist2 :('a -> 'b -> 'c -> 'c) -> 'a list -> 'b list -> 'c -> 'c
  val end_itlist : ('a -> 'a -> 'a) -> 'a list -> 'a
  val zip : 'a list -> 'b list -> ('a * 'b) list
  val combine : 'a list * 'b list -> ('a * 'b) list
  val unzip : ('a * 'b) list -> 'a list * 'b list
  val split : ('a * 'b) list -> 'a list * 'b list
  val mapfilter : ('a -> 'b) -> 'a list -> 'b list
  val flatten : 'a list list -> 'a list
  val pluck : ('a -> bool) -> 'a list -> 'a * 'a list
  val enumerate : int -> 'a list -> (int * 'a) list
  val assoc : ''a -> (''a * 'b) list -> 'b
  val assoc1 : ''a -> (''a * 'b) list -> (''a * 'b) option
  val assoc2 : ''a -> ('b * ''a) list -> ('b * ''a) option
  type ('a,'b) subst = {redex:'a, residue:'b} list
  val subst_assoc : ('a -> bool) -> ('a,'b)subst -> 'b option
  val |-> :('a * 'b) -> {redex:'a, residue:'b}
  val mem : ''a -> ''a list -> bool
  val insert : ''a -> ''a list -> ''a list
  val mk_set : ''a list -> ''a list
  val union : ''a list -> ''a list -> ''a list
  val U : ''a list list -> ''a list
  val set_diff : ''a list -> ''a list -> ''a list
  val subtract : ''a list -> ''a list -> ''a list
  val intersect : ''a list -> ''a list -> ''a list
  val null_intersection : ''a list -> ''a list -> bool
  val set_eq : ''a list -> ''a list -> bool
  val op_mem : ('a -> 'a -> bool) -> 'a -> 'a list -> bool
  val op_insert : ('a -> 'a -> bool) -> 'a -> 'a list -> 'a list
  val op_union : ('a -> 'a -> bool) -> 'a list -> 'a list -> 'a list
  val op_mk_set: ('a -> 'a -> bool) -> 'a list -> 'a list
  val op_U : ('a -> 'a -> bool) -> 'a list list -> 'a list
  val op_intersect: ('a -> 'a -> bool) -> 'a list -> 'a list -> 'a list
  val op_set_diff: ('a -> 'a -> bool) -> 'a list -> 'a list -> 'a list
  val for : int -> int -> (int -> 'a) -> 'a list
  val for_se : int -> int -> (int -> 'a) -> unit
  val list_of_array : 'a array -> 'a list
  val int_to_string : int -> string
  val string_to_int : string -> int
  val sort : ('a -> 'a -> bool) -> 'a list -> 'a list
  val int_sort : int list -> int list

  val start_time : unit -> Timer.cpu_timer
  val end_time   : Timer.cpu_timer -> unit
  val time       : ('a -> 'b) -> 'a -> 'b

  type ('a,'b) istream
  val mk_istream : ('a -> 'a) -> 'a -> ('a -> 'b) -> ('a,'b) istream
  val next : ('a,'b) istream -> ('a,'b) istream
  val state : ('a,'b) istream -> 'b
  val reset : ('a,'b) istream -> ('a,'b) istream

  val say : string -> unit
  val quote : string -> string
  val words2 : string -> string -> string list
  val commafy : string list -> string list
  val prime : string -> string

  val front_last : 'a list -> 'a list * 'a
  val last : 'a list -> 'a 
  val funpow : int -> ('a -> 'a) -> 'a -> 'a
  val mesg : bool -> string -> unit
  val with_flag :'a ref * 'a -> ('b -> 'c) -> 'b -> 'c
  val hash : int -> string -> int*int -> int
  datatype ('a,'b) sum = LEFT of 'a 
                       | RIGHT of 'b
end
