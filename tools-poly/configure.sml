(* ----------------------------------------------------------------------
              HOL configuration script


   DO NOT EDIT THIS FILE UNLESS YOU HAVE TRIED AND FAILED WITH

     smart-configure

   AND

     config-override.

   ---------------------------------------------------------------------- *)


(* Uncomment these lines and fill in correct values if smart-configure doesn't
   get the correct values itself.  Then run

      poly < tools/configure.sml

   If you are specifying directories under Windows, we recommend you
   use forward slashes (the "/" character) as a directory separator,
   rather than the 'traditional' backslash (the "\" character).

   The problem with the latter is that you have to double them up
   (i.e., write "\\") in order to 'escape' them and make the string
   valid for SML.  For example, write "c:/dir1/dir2/mosml", rather
   than "c:\\dir1\\dir2\\mosml", and certainly DON'T write
   "c:\dir1\dir2\mosml".
*)

(*
val poly : string         =
val polymllibdir : string =
val holdir :string        =
val OS :string            =
                           (* Operating system; choices are:
                                "linux", "solaris", "unix", "macosx",
                                "winNT"   *)
*)

val _ = PolyML.print_depth 0;

val CC:string       = "gcc";      (* C compiler                       *)
val GNUMAKE:string  = "make";     (* for bdd library and SMV          *)
val DEPDIR:string   = ".HOLMK";   (* where Holmake dependencies kept  *)


local
   fun assoc item =
      let
         fun assc ((key,ob)::rst) = if item=key then ob else assc rst
           | assc [] = raise Match
      in
         assc
      end
   val machine_env = Posix.ProcEnv.uname ()
   val sysname = assoc "sysname" machine_env
   val intOf = Option.valOf o Int.fromString
in
   val machine_flags =
       if sysname = "Darwin" (* Mac OS X *) then
         let
           open PolyML
           val vnum_s = hd (String.fields Char.isSpace Compiler.compilerVersion)
           val (major,minor,point) =
              case String.fields (fn c => c = #".") vnum_s of
                 [mj] => (intOf mj, 0, 0)
               | [mj, mn] => (intOf mj, intOf mn, 0)
               | [mj, mn, pt] => (intOf mj, intOf mn, intOf pt)
               | _ => die "Can't pull apart Compiler.compilerVersion"
           val number = major * 100 + 10 * minor + point
         in
           (if number >= 551
               then ["-lpthread", "-lm", "-ldl", "-lstdc++",
                     "-Wl,-no_pie"]
            else if number >= 550
               then ["-Wl,-no_pie"]
            else ["-segprot", "POLY", "rwx", "rwx"]) @
           (if PolyML.architecture() = "I386" then ["-arch", "i386"]
            else [])
         end
       else []
end;

fun compile systeml exe obj =
  (systeml ([CC, "-o", exe, obj, "-L" ^ polymllibdir,
             "-lpolymain", "-lpolyml"] @ machine_flags);
   OS.FileSys.remove obj);

(*---------------------------------------------------------------------------
          END user-settable parameters
 ---------------------------------------------------------------------------*)

val version_number = 9
val release_string = "Kananaskis"

(*
val _ = Meta.quietdec := true;
app load ["OS", "Substring", "BinIO", "Lexing", "Nonstdio"];
*)
structure FileSys = OS.FileSys
structure Process = OS.Process
structure Path = OS.Path

fun check_is_dir role dir =
    (FileSys.isDir dir handle e => false) orelse
    (print "\n*** Bogus directory ("; print dir; print ") given for ";
     print role; print "! ***\n";
     Process.exit Process.failure)

val _ = check_is_dir "polymllibdir" polymllibdir
val _ = check_is_dir "holdir" holdir
val _ =
    if List.exists (fn s => s = OS)
                   ["linux", "solaris", "unix", "winNT", "macosx"]
    then ()
    else (print ("\n*** Bad OS specified: "^OS^" ***\n");
          Process.exit Process.failure)

fun normPath s = Path.toString(Path.fromString s)
fun itstrings f [] = raise Fail "itstrings: empty list"
  | itstrings f [x] = x
  | itstrings f (h::t) = f h (itstrings f t);

fun fullPath slist = normPath
   (itstrings (fn chunk => fn path => Path.concat (chunk,path)) slist);

fun quote s = String.concat ["\"",String.toString s,"\""]

val holmakedir = fullPath [holdir, "tools-poly", "Holmake"];

(*---------------------------------------------------------------------------
      File handling. The following implements a very simple line
      replacement function: it searchs the source file for a line that
      contains "redex" and then replaces the whole line by "residue". As it
      searches, it copies lines to the target. Each replacement happens
      once; the replacements occur in order. After the last replacement
      is done, the rest of the source is copied to the target.
 ---------------------------------------------------------------------------*)

fun processLinesUntil (istrm,ostrm) (redex,residue) =
 let open TextIO
     fun loop () =
       case inputLine istrm
        of NONE => ()
          | SOME ""   => ()
         | SOME line =>
            let val ssline = Substring.full line
                val (pref, suff) = Substring.position redex ssline
            in
              if Substring.size suff > 0
              then output(ostrm, residue)
              else (output(ostrm, line); loop())
            end
 in
   loop()
 end;

fun fill_holes (src,target) repls =
 let open TextIO
     val istrm = openIn src
     val ostrm = openOut target
  in
     List.app (processLinesUntil (istrm, ostrm)) repls;
     output(ostrm, inputAll istrm);
     closeIn istrm; closeOut ostrm
  end;

infix -->
fun (x --> y) = (x,y);

fun text_copy src dest = fill_holes(src, dest) [];

fun bincopy src dest = let
  val instr = BinIO.openIn src
  val outstr = BinIO.openOut dest
  fun loop () = let
    val v = BinIO.inputN(instr, 1024)
  in
    if Word8Vector.length v = 0 then (BinIO.flushOut outstr;
                                      BinIO.closeOut outstr;
                                      BinIO.closeIn instr)
    else (BinIO.output(outstr, v); loop())
  end
in
  loop()
end;


(*---------------------------------------------------------------------------
     Generate "Systeml" file in tools-poly/Holmake and then load in that file,
     thus defining the Systeml structure for the rest of the configuration
     (with OS-specific stuff available).
 ---------------------------------------------------------------------------*)

(* default values ensure that later things fail if Systeml doesn't compile *)
fun systeml x = (print "Systeml not correctly loaded.\n";
                 Process.exit Process.failure);
val mk_xable = systeml;
val xable_string = systeml;

val OSkind = if OS="linux" orelse OS="solaris" orelse OS="macosx" then "unix"
             else OS
val _ = let
  (* copy system-specific implementation of Systeml into place *)
  val srcfile = fullPath [holmakedir, OSkind ^"-systeml.sml"]
  val destfile = fullPath [holmakedir, "Systeml.sml"]
  val sigfile = fullPath [holdir, "tools", "Holmake", "Systeml.sig"]
in
  print "\nLoading system specific functions\n";
  use sigfile;
  fill_holes (srcfile, destfile)
  ["val HOLDIR ="   --> ("val HOLDIR = "^quote holdir^"\n"),
   "val POLYMLLIBDIR =" --> ("val POLYMLLIBDIR = "^quote polymllibdir^"\n"),
   "val POLY =" --> ("val POLY = "^quote poly^"\n"),
   "val POLY_LDFLAGS =" --> ("val POLY_LDFLAGS = ["^
                             (String.concatWith
                                  ", "
                                  (quote ("-L"^polymllibdir)::
                                   quote "-lpolymain" ::
                                   quote "-lpolyml" ::
                                   map quote machine_flags)) ^ "]\n"),
   "val POLY_LDFLAGS_STATIC =" --> ("val POLY_LDFLAGS_STATIC = ["^
                             (String.concatWith
                                  ", "
                                  (quote ("-L"^polymllibdir)::
                                   quote "-lpolymain" ::
                                   quote "-lpolyml" ::
                                   quote "-static" ::
                                   quote "-lpolyml" ::
                                   quote "-lstdc++" ::
                                   quote "-lm" ::
                                   quote "-ldl" ::
                                   quote "-lpthread" ::
                                   map quote machine_flags)) ^ "]\n"),
   "val CC =" --> ("val CC = "^quote CC^"\n"),
   "val OS ="       --> ("val OS = "^quote OS^"\n"),
   "val DEPDIR ="   --> ("val DEPDIR = "^quote DEPDIR^"\n"),
   "val GNUMAKE ="  --> ("val GNUMAKE = "^quote GNUMAKE^"\n"),
   "val DYNLIB ="   --> ("val DYNLIB = "^Bool.toString dynlib_available^"\n"),
   "val version ="  --> ("val version = "^Int.toString version_number^"\n"),
   "val ML_SYSNAME =" --> "val ML_SYSNAME = \"poly\"\n",
   "val release ="  --> ("val release = "^quote release_string^"\n"),
   "val DOT_PATH =" --> ("val DOT_PATH = "^quote DOT_PATH^"\n")];
  use destfile
end;

open Systeml;

(*---------------------------------------------------------------------------
     Now compile Systeml.sml in tools-poly/Holmake/
 ---------------------------------------------------------------------------*)

fun canread s = OS.FileSys.access(s, [FileSys.A_READ])
val modTime = OS.FileSys.modTime;

let
  val _ = print "Compiling system specific functions ("
  val sigfile = fullPath [holdir, "tools", "Holmake", "Systeml.sig"]
  val uifile = fullPath [holdir, "sigobj", "Systeml.ui"]
  fun to_sigobj s = bincopy s (fullPath [holdir, "sigobj", Path.file s])
  val uifile_content =
      fullPath [holdir, "sigobj", "Systeml.sig"] ^ "\n"
in
  if not (canread uifile) orelse
     Time.>(modTime sigfile, modTime uifile) orelse
     OS.FileSys.fileSize uifile > size uifile_content
     (* if the file is this large it's been generated by Moscow ML, or is
        otherwise wrong *)
  then
    let
      val oo = TextIO.openOut uifile
    in
      (* note how this is "compiling" straight into sigobj, rather than
         doing anything in the source directory, tools/Holmake *)
      TextIO.output (oo, uifile_content);
      TextIO.closeOut oo;
      print "sig "
    end
  else ();
  to_sigobj sigfile;
  let val oo = TextIO.openOut (fullPath [holdir, "sigobj", "Systeml.uo"])
  in
    TextIO.output (oo, fullPath [holdir, "sigobj", "Systeml.sml"] ^ "\n");
    TextIO.closeOut oo
  end;
  to_sigobj (fullPath [holmakedir, "Systeml.sml"]);
  print "sml)\n"
end;



(*---------------------------------------------------------------------------
          String and path operations.
 ---------------------------------------------------------------------------*)

fun echo s = (TextIO.output(TextIO.stdOut, s^"\n");
              TextIO.flushOut TextIO.stdOut);

val _ = echo "Beginning configuration.";

(* ----------------------------------------------------------------------
    remove the quotation filter from the bin directory, if it exists
  ---------------------------------------------------------------------- *)

val _ = let
  val unquote = fullPath [holdir, "bin", xable_string "unquote"]
in
  if FileSys.access(unquote, [FileSys.A_READ]) then
    (print "Removing old quotation filter from bin/\n";
     FileSys.remove unquote
     handle Thread.Thread.Interrupt => raise Thread.Thread.Interrupt
          | _ => print "*** Tried to remove quotation filter from bin/ but \
                       \couldn't!  Proceeding anyway.\n")
  else ()
end



fun die s = (print s; print "\n"; Process.exit Process.failure)

local
  val cdir = FileSys.getDir()
  val systeml = fn clist => if not (Process.isSuccess (systeml clist)) then
                              raise (Fail "")
                            else ()
  val toolsdir = fullPath [holdir, "tools-poly"]
  val lexdir = fullPath [holdir, "tools", "mllex"]
  val yaccdir = fullPath [holdir, "tools", "mlyacc"]
  val qfdir = fullPath [holdir, "tools", "quote-filter"]
  val hmakedir = fullPath [toolsdir, "Holmake"]
  val hmakebin = fullPath [holdir, "bin", "Holmake"]
  val buildbin = fullPath [holdir, "bin", "build"]
  val qfbin = fullPath [holdir, "bin", "unquote"]
  val lexer = fullPath [lexdir, "mllex.exe"]
  val yaccer = fullPath [yaccdir, "src", "mlyacc.exe"]
  fun copyfile from to =
    let val instrm = BinIO.openIn from
        val ostrm = BinIO.openOut to
        val v = BinIO.inputAll instrm
    in
      BinIO.output(ostrm, v);
      BinIO.closeIn instrm;
      BinIO.closeOut ostrm
    end;
  fun remove f = (FileSys.remove f handle OS.SysErr _ => ())
in

(* Remove old files *)

val _ = remove hmakebin;
val _ = remove buildbin;
val _ = remove lexer;
val _ = remove yaccer;
val _ = remove qfbin;
val _ = remove (fullPath [hmakedir, "Lexer.lex.sml"]);
val _ = remove (fullPath [hmakedir, "Parser.grm.sig"]);
val _ = remove (fullPath [hmakedir, "Parser.grm.sml"]);


(* ----------------------------------------------------------------------
    Compile our local copy of mllex
   ---------------------------------------------------------------------- *)
val _ =
  (echo "Making tools/mllex/mllex.exe.";
   FileSys.chDir lexdir;
   system_ps (POLY ^ " < poly-mllex.ML");
   compile systeml "mllex.exe" "mllex.o";
   mk_xable "../../tools/mllex/mllex.exe";
   FileSys.chDir cdir)
   handle _ => die "Failed to build mllex.";

(* ----------------------------------------------------------------------
    Compile our local copy of mlyacc
   ---------------------------------------------------------------------- *)
val _ =
  (echo "Making tools/mlyacc/mlyacc.exe.";
   FileSys.chDir yaccdir;
   FileSys.chDir "src";
   systeml [lexer, "yacc.lex"];
   FileSys.chDir yaccdir;
   system_ps (POLY ^ " < poly-mlyacc.ML");
   compile systeml yaccer "mlyacc.o";
   mk_xable "../../tools/mlyacc/src/mlyacc.exe";
   FileSys.chDir cdir)
   handle _ => die "Failed to build mlyacc.";

(* ----------------------------------------------------------------------
    Compile quote-filter
   ---------------------------------------------------------------------- *)
val _ =
  (echo "Making bin/unquote.";
   FileSys.chDir qfdir;
   systeml [lexer, "filter"];
   system_ps (POLY ^  " < poly-unquote.ML");
   compile systeml qfbin "unquote.o";
   FileSys.chDir cdir)
   handle _ => die "Failed to build unquote.";

(*---------------------------------------------------------------------------
    Compile Holmake (bypassing the makefile in directory Holmake), then
    put the executable bin/Holmake.
 ---------------------------------------------------------------------------*)
val _ =
  (echo "Making bin/Holmake";
   FileSys.chDir hmakedir;
   systeml [lexer, "Lexer.lex"];
   systeml [yaccer, "Parser.grm"];
   FileSys.chDir toolsdir;
   system_ps (POLY ^ " < " ^ fullPath ["Holmake", "poly-Holmake.ML"]);
   compile systeml hmakebin (fullPath ["Holmake", "Holmake.o"]);
   FileSys.chDir cdir)
   handle _ => die "Failed to build Holmake.";

(*---------------------------------------------------------------------------
    Compile build.sml, and put it in bin/build.
 ---------------------------------------------------------------------------*)
val _ =
  (echo "Making bin/build.";
   FileSys.chDir toolsdir;
   system_ps (POLY ^ " < poly-build.ML");
   compile systeml buildbin "build.o";
   FileSys.chDir cdir)
   handle _ => die "Failed to build build.";

(* ----------------------------------------------------------------------
    Generate heapname executable
   ---------------------------------------------------------------------- *)

val _ = let
in
  echo "Making bin/heapname utility";
  FileSys.chDir toolsdir;
  system_ps (POLY ^ " < heapname.ML");
  compile systeml (fullPath [HOLDIR,"bin","heapname"]) "heapname.o";
  FileSys.chDir cdir
end handle _ => die "Failed to build heapname."

(* ----------------------------------------------------------------------
    Generate buildheap executable
   ---------------------------------------------------------------------- *)
val _ = let
in
  echo "Making bin/buildheap utility";
  FileSys.chDir toolsdir;
  system_ps (POLY ^ " < buildheap.ML");
  compile systeml (fullPath [HOLDIR, "bin", "buildheap"]) "buildheap.o";
  FileSys.chDir cdir
end handle _ => die "Failed to build buildheap."


end (* local *)

(*---------------------------------------------------------------------------
    Instantiate tools/hol-mode.src, and put it in tools/hol-mode.el
 ---------------------------------------------------------------------------*)

val _ =
 let open TextIO
     val _ = echo "Making hol-mode.el (for Emacs/XEmacs)"
     val src = fullPath [holdir, "tools", "hol-mode.src"]
    val target = fullPath [holdir, "tools", "hol-mode.el"]
 in
    fill_holes (src, target)
      ["(defcustom hol-executable HOL-EXECUTABLE\n"
        -->
       ("(defcustom hol-executable \n  "^
        quote (fullPath [holdir, "bin", "hol"])^"\n"),
       "(defcustom holmake-executable HOLMAKE-EXECUTABLE\n"
        -->
       ("(defcustom holmake-executable \n  "^
        quote (fullPath [holdir, "bin/Holmake"])^"\n")]
 end;

(*---------------------------------------------------------------------------
    Instantiate tools/vim/*.src
 ---------------------------------------------------------------------------*)

val _ =
  let open TextIO
    val _ = echo "Making tools/vim/*"
    val pref = fullPath [holdir, "tools", "vim"]
    val src1 = fullPath [pref, "hol.src"]
    val tar1 = fullPath [pref, "hol.vim"]
    val src2 = fullPath [pref, "vimhol.src"]
    val tar2 = fullPath [pref, "vimhol.sml"]
    val tar3 = openOut (fullPath [pref, "hol-config.sml"])
    val tar4 = openOut (fullPath [pref, "filetype.vim"])
    fun qstr s = (quote s)^"\n"
    val holpipe = qstr(fullPath [pref, "fifo"])
    val tmpprefix = qstr("/tmp/vimhol")
  in
    fill_holes (src1,tar1)
      ["let s:holpipe =" -->
       "let s:holpipe = "^holpipe,
       "let s:tmpprefix =" -->
       "let s:tmpprefix = "^tmpprefix];
    fill_holes (src2,tar2)
      ["val fifoPath ="-->
       "val fifoPath = "^holpipe];
    output(tar3, "use "^(qstr tar2));
    closeOut tar3;
    output(tar4,"augroup filetypedetect\n");
    output(tar4,"  au BufRead,BufNewFile *?Script.sml let maplocalleader = \"h\" | source "^tar1^"\n");
    output(tar4,"  \"Uncomment the line below to automatically load Unicode\n");
    output(tar4,"  \"au BufRead,BufNewFile *?Script.sml source "^fullPath [pref, "holabs.vim"]^"\n");
    output(tar4,"augroup END\n");
    closeOut tar4
  end;





(*---------------------------------------------------------------------------
      Generate shell scripts for running HOL.
 ---------------------------------------------------------------------------*)

val _ =
   let
      val _ = echo "Generating bin/hol."
      val target      = fullPath [holdir, "bin", "hol.bare"]
      val target_boss = fullPath [holdir, "bin", "hol"]
      val hol0_heap   = protect(fullPath[HOLDIR,"bin", "hol.builder0"]) ^ " -i"
      val hol_heapcalc= "$(" ^ protect(fullPath[HOLDIR,"bin","heapname"]) ^
                        ") --gcthreads=1 -i"
      val prelude = ["prelude.ML"]
      val prelude2 = prelude @ ["prelude2.ML"]
   in
      (* "unquote" scripts use the unquote executable to provide nice
         handling of double-backquote characters *)
      emit_hol_unquote_script target hol0_heap prelude;
      emit_hol_unquote_script target_boss hol_heapcalc prelude2;
      emit_hol_script (target ^ ".noquote") hol0_heap prelude;
      emit_hol_script (target_boss ^ ".noquote") hol_heapcalc prelude2
   end

val _ = print "\nFinished configuration!\n"
