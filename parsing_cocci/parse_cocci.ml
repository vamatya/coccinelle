(* splits the entire file into minus and plus fragments, and parses each
separately (thus duplicating work for the parsing of the context elements) *)

module D = Data
module PC = Parser_cocci_menhir
module V0 = Visitor_ast0
module VT0 = Visitor_ast0_types
module Ast = Ast_cocci
module Ast0 = Ast0_cocci
let pr = Printf.sprintf
(*let pr2 s = prerr_string s; prerr_string "\n"; flush stderr*)
let pr2 s = Printf.printf "%s\n" s

(* for isomorphisms.  all should be at the front!!! *)
let reserved_names =
  ["all";"optional_storage";"optional_qualifier";"value_format";"comm_assoc"]

(* ----------------------------------------------------------------------- *)
(* Debugging... *)

let line_type (d,_,_,_,_,_,_,_) = d

let line_type2c tok =
  match line_type tok with
    D.MINUS | D.OPTMINUS | D.UNIQUEMINUS -> ":-"
  | D.PLUS -> ":+"
  | D.CONTEXT | D.UNIQUE | D.OPT -> ""

let token2c (tok,_) =
 match tok with
    PC.TIdentifier -> "identifier"
  | PC.TType -> "type"
  | PC.TParameter -> "parameter"
  | PC.TConstant -> "constant"
  | PC.TExpression -> "expression"
  | PC.TIdExpression -> "idexpression"
  | PC.TInitialiser -> "initialiser"
  | PC.TStatement -> "statement"
  | PC.TPosition -> "position"
  | PC.TPosAny -> "any"
  | PC.TFunction -> "function"
  | PC.TLocal -> "local"
  | PC.Tlist -> "list"
  | PC.TFresh -> "fresh"
  | PC.TCppConcatOp -> "##"
  | PC.TPure -> "pure"
  | PC.TContext -> "context"
  | PC.TTypedef -> "typedef"
  | PC.TDeclarer -> "declarer"
  | PC.TIterator -> "iterator"
  | PC.TName -> "name"
  | PC.TRuleName str -> "rule_name-"^str
  | PC.TUsing -> "using"
  | PC.TVirtual -> "virtual"
  | PC.TPathIsoFile str -> "path_iso_file-"^str
  | PC.TDisable -> "disable"
  | PC.TExtends -> "extends"
  | PC.TDepends -> "depends"
  | PC.TOn -> "on"
  | PC.TEver -> "ever"
  | PC.TNever -> "never"
  | PC.TExists -> "exists"
  | PC.TForall -> "forall"
  | PC.TError -> "error"
  | PC.TWords -> "words"
  | PC.TGenerated -> "generated"

  | PC.TNothing -> "nothing"

  | PC.Tchar(clt) -> "char"^(line_type2c  clt)
  | PC.Tshort(clt) -> "short"^(line_type2c clt)
  | PC.Tint(clt) -> "int"^(line_type2c clt)
  | PC.Tdouble(clt) -> "double"^(line_type2c clt)
  | PC.Tfloat(clt) -> "float"^(line_type2c clt)
  | PC.Tlong(clt) -> "long"^(line_type2c clt)
  | PC.Tvoid(clt) -> "void"^(line_type2c clt)
  | PC.Tstruct(clt) -> "struct"^(line_type2c clt)
  | PC.Tunion(clt) -> "union"^(line_type2c clt)
  | PC.Tenum(clt) -> "enum"^(line_type2c clt)
  | PC.Tunsigned(clt) -> "unsigned"^(line_type2c clt)
  | PC.Tsigned(clt) -> "signed"^(line_type2c clt)
  | PC.Tstatic(clt) -> "static"^(line_type2c clt)
  | PC.Tinline(clt) -> "inline"^(line_type2c clt)
  | PC.Ttypedef(clt) -> "typedef"^(line_type2c clt)
  | PC.Tattr(s,clt) -> s^(line_type2c clt)
  | PC.Tauto(clt) -> "auto"^(line_type2c clt)
  | PC.Tregister(clt) -> "register"^(line_type2c clt)
  | PC.Textern(clt) -> "extern"^(line_type2c clt)
  | PC.Tconst(clt) -> "const"^(line_type2c clt)
  | PC.Tvolatile(clt) -> "volatile"^(line_type2c clt)

  | PC.TPragma(s,_) -> s
  | PC.TIncludeL(s,clt) -> (pr "#include \"%s\"" s)^(line_type2c clt)
  | PC.TIncludeNL(s,clt) -> (pr "#include <%s>" s)^(line_type2c clt)
  | PC.TDefine(clt,_) -> "#define"^(line_type2c clt)
  | PC.TDefineParam(clt,_,_,_) -> "#define_param"^(line_type2c clt)
  | PC.TMinusFile(s,clt) -> (pr "--- %s" s)^(line_type2c clt)
  | PC.TPlusFile(s,clt) -> (pr "+++ %s" s)^(line_type2c clt)

  | PC.TInc(clt) -> "++"^(line_type2c clt)
  | PC.TDec(clt) -> "--"^(line_type2c clt)

  | PC.TIf(clt) -> "if"^(line_type2c clt)
  | PC.TElse(clt) -> "else"^(line_type2c clt)
  | PC.TWhile(clt) -> "while"^(line_type2c clt)
  | PC.TFor(clt) -> "for"^(line_type2c clt)
  | PC.TDo(clt) -> "do"^(line_type2c clt)
  | PC.TSwitch(clt) -> "switch"^(line_type2c clt)
  | PC.TCase(clt) -> "case"^(line_type2c clt)
  | PC.TDefault(clt) -> "default"^(line_type2c clt)
  | PC.TReturn(clt) -> "return"^(line_type2c clt)
  | PC.TBreak(clt) -> "break"^(line_type2c clt)
  | PC.TContinue(clt) -> "continue"^(line_type2c clt)
  | PC.TGoto(clt) -> "goto"^(line_type2c clt)
  | PC.TIdent(s,clt) -> (pr "ident-%s" s)^(line_type2c clt)
  | PC.TTypeId(s,clt) -> (pr "typename-%s" s)^(line_type2c clt)
  | PC.TDeclarerId(s,clt) -> (pr "declarername-%s" s)^(line_type2c clt)
  | PC.TIteratorId(s,clt) -> (pr "iteratorname-%s" s)^(line_type2c clt)
  | PC.TMetaDeclarer(_,_,_,clt) -> "declmeta"^(line_type2c clt)
  | PC.TMetaIterator(_,_,_,clt) -> "itermeta"^(line_type2c clt)

  | PC.TSizeof(clt) -> "sizeof"^(line_type2c clt)

  | PC.TString(x,clt) -> x^(line_type2c clt)
  | PC.TChar(x,clt) -> x^(line_type2c clt)
  | PC.TFloat(x,clt) -> x^(line_type2c clt)
  | PC.TInt(x,clt) -> x^(line_type2c clt)

  | PC.TOrLog(clt) -> "||"^(line_type2c clt)
  | PC.TAndLog(clt) -> "&&"^(line_type2c clt)
  | PC.TOr(clt) -> "|"^(line_type2c clt)
  | PC.TXor(clt) -> "^"^(line_type2c clt)
  | PC.TAnd (clt) -> "&"^(line_type2c clt)
  | PC.TEqEq(clt) -> "=="^(line_type2c clt)
  | PC.TNotEq(clt) -> "!="^(line_type2c clt)
  | PC.TLogOp(op,clt) ->
      (match op with
	Ast.Inf -> "<"
      |	Ast.InfEq -> "<="
      |	Ast.Sup -> ">"
      |	Ast.SupEq -> ">="
      |	_ -> failwith "not possible")
      ^(line_type2c clt)
  | PC.TShOp(op,clt) ->
      (match op with
	Ast.DecLeft -> "<<"
      |	Ast.DecRight -> ">>"
      |	_ -> failwith "not possible")
      ^(line_type2c clt)
  | PC.TPlus(clt) -> "+"^(line_type2c clt)
  | PC.TMinus(clt) -> "-"^(line_type2c clt)
  | PC.TMul(clt) -> "*"^(line_type2c clt)
  | PC.TDmOp(op,clt) ->
      (match op with
	Ast.Div -> "/"
      |	Ast.Mod -> "%"
      |	_ -> failwith "not possible")
      ^(line_type2c clt)
  | PC.TTilde (clt) -> "~"^(line_type2c clt)

  | PC.TMetaParam(_,_,clt) -> "parammeta"^(line_type2c clt)
  | PC.TMetaParamList(_,_,_,clt) -> "paramlistmeta"^(line_type2c clt)
  | PC.TMetaConst(_,_,_,_,clt) -> "constmeta"^(line_type2c clt)
  | PC.TMetaErr(_,_,_,clt) -> "errmeta"^(line_type2c clt)
  | PC.TMetaExp(_,_,_,_,clt) -> "expmeta"^(line_type2c clt)
  | PC.TMetaIdExp(_,_,_,_,clt) -> "idexpmeta"^(line_type2c clt)
  | PC.TMetaLocalIdExp(_,_,_,_,clt) -> "localidexpmeta"^(line_type2c clt)
  | PC.TMetaExpList(_,_,_,clt) -> "explistmeta"^(line_type2c clt)
  | PC.TMetaId(_,_,_,clt)    -> "idmeta"^(line_type2c clt)
  | PC.TMetaType(_,_,clt)    -> "typemeta"^(line_type2c clt)
  | PC.TMetaInit(_,_,clt)    -> "initmeta"^(line_type2c clt)
  | PC.TMetaStm(_,_,clt)   -> "stmmeta"^(line_type2c clt)
  | PC.TMetaStmList(_,_,clt)   -> "stmlistmeta"^(line_type2c clt)
  | PC.TMetaFunc(_,_,_,clt)  -> "funcmeta"^(line_type2c clt)
  | PC.TMetaLocalFunc(_,_,_,clt) -> "funcmeta"^(line_type2c clt)
  | PC.TMetaPos(_,_,_,clt)   -> "posmeta"
  | PC.TMPtVirg -> ";"
  | PC.TArobArob -> "@@"
  | PC.TArob -> "@"
  | PC.TPArob -> "P@"
  | PC.TScript -> "script"
  | PC.TInitialize -> "initialize"
  | PC.TFinalize -> "finalize"

  | PC.TWhen(clt) -> "WHEN"^(line_type2c clt)
  | PC.TWhenTrue(clt) -> "WHEN TRUE"^(line_type2c clt)
  | PC.TWhenFalse(clt) -> "WHEN FALSE"^(line_type2c clt)
  | PC.TAny(clt) -> "ANY"^(line_type2c clt)
  | PC.TStrict(clt) -> "STRICT"^(line_type2c clt)
  | PC.TEllipsis(clt) -> "..."^(line_type2c clt)
(*
  | PC.TCircles(clt)  -> "ooo"^(line_type2c clt)
  | PC.TStars(clt)    -> "***"^(line_type2c clt)
*)

  | PC.TOEllipsis(clt) -> "<..."^(line_type2c clt)
  | PC.TCEllipsis(clt) -> "...>"^(line_type2c clt)
  | PC.TPOEllipsis(clt) -> "<+..."^(line_type2c clt)
  | PC.TPCEllipsis(clt) -> "...+>"^(line_type2c clt)
(*
  | PC.TOCircles(clt)  -> "<ooo"^(line_type2c clt)
  | PC.TCCircles(clt)  -> "ooo>"^(line_type2c clt)
  | PC.TOStars(clt)    -> "<***"^(line_type2c clt)
  | PC.TCStars(clt)    -> "***>"^(line_type2c clt)
*)
  | PC.TBang0 -> "!"
  | PC.TPlus0 -> "+"
  | PC.TWhy0  -> "?"

  | PC.TWhy(clt)   -> "?"^(line_type2c clt)
  | PC.TDotDot(clt)   -> ":"^(line_type2c clt)
  | PC.TBang(clt)  -> "!"^(line_type2c clt)
  | PC.TOPar(clt)  -> "("^(line_type2c clt)
  | PC.TOPar0(clt) -> "("^(line_type2c clt)
  | PC.TMid0(clt)  -> "|"^(line_type2c clt)
  | PC.TCPar(clt)  -> ")"^(line_type2c clt)
  | PC.TCPar0(clt) -> ")"^(line_type2c clt)

  | PC.TOBrace(clt) -> "{"^(line_type2c clt)
  | PC.TCBrace(clt) -> "}"^(line_type2c clt)
  | PC.TOCro(clt) -> "["^(line_type2c clt)
  | PC.TCCro(clt) -> "]"^(line_type2c clt)
  | PC.TOInit(clt) -> "{"^(line_type2c clt)

  | PC.TPtrOp(clt) -> "->"^(line_type2c clt)

  | PC.TEq(clt) -> "="^(line_type2c clt)
  | PC.TAssign(_,clt) -> "=op"^(line_type2c clt)
  | PC.TDot(clt) -> "."^(line_type2c clt)
  | PC.TComma(clt) -> ","^(line_type2c clt)
  | PC.TPtVirg(clt) -> ";"^(line_type2c clt)

  | PC.EOF -> "eof"
  | PC.TLineEnd(clt) -> "line end"
  | PC.TInvalid -> "invalid"
  | PC.TFunDecl(clt) -> "fundecl"

  | PC.TIso -> "<=>"
  | PC.TRightIso -> "=>"
  | PC.TIsoTopLevel -> "TopLevel"
  | PC.TIsoExpression -> "Expression"
  | PC.TIsoArgExpression -> "ArgExpression"
  | PC.TIsoTestExpression -> "TestExpression"
  | PC.TIsoStatement -> "Statement"
  | PC.TIsoDeclaration -> "Declaration"
  | PC.TIsoType -> "Type"
  | PC.TScriptData s -> s

let print_tokens s tokens =
  Printf.printf "%s\n" s;
  List.iter (function x -> Printf.printf "%s " (token2c x)) tokens;
  Printf.printf "\n\n";
  flush stdout

type plus = PLUS | NOTPLUS | SKIP

let plus_attachable only_plus (tok,_) =
  match tok with
    PC.Tchar(clt) | PC.Tshort(clt) | PC.Tint(clt) | PC.Tdouble(clt)
  | PC.Tfloat(clt) | PC.Tlong(clt) | PC.Tvoid(clt) | PC.Tstruct(clt)
  | PC.Tunion(clt) | PC.Tenum(clt) | PC.Tunsigned(clt) | PC.Tsigned(clt)
  | PC.Tstatic(clt)
  | PC.Tinline(clt) | PC.Ttypedef(clt) | PC.Tattr(_,clt)
  | PC.Tauto(clt) | PC.Tregister(clt)
  | PC.Textern(clt) | PC.Tconst(clt) | PC.Tvolatile(clt)

  | PC.TIncludeL(_,clt) | PC.TIncludeNL(_,clt) | PC.TDefine(clt,_)
  | PC.TDefineParam(clt,_,_,_) | PC.TMinusFile(_,clt) | PC.TPlusFile(_,clt)

  | PC.TInc(clt) | PC.TDec(clt)

  | PC.TIf(clt) | PC.TElse(clt) | PC.TWhile(clt) | PC.TFor(clt) | PC.TDo(clt)
  | PC.TSwitch(clt) | PC.TCase(clt) | PC.TDefault(clt) | PC.TReturn(clt)
  | PC.TBreak(clt) | PC.TContinue(clt) | PC.TGoto(clt) | PC.TIdent(_,clt)
  | PC.TTypeId(_,clt) | PC.TDeclarerId(_,clt) | PC.TIteratorId(_,clt)

  | PC.TSizeof(clt)

  | PC.TString(_,clt) | PC.TChar(_,clt) | PC.TFloat(_,clt) | PC.TInt(_,clt)

  | PC.TOrLog(clt) | PC.TAndLog(clt) | PC.TOr(clt) | PC.TXor(clt)
  | PC.TAnd (clt) | PC.TEqEq(clt) | PC.TNotEq(clt) | PC.TLogOp(_,clt)
  | PC.TShOp(_,clt) | PC.TPlus(clt) | PC.TMinus(clt) | PC.TMul(clt)
  | PC.TDmOp(_,clt) | PC.TTilde (clt)

  | PC.TMetaParam(_,_,clt) | PC.TMetaParamList(_,_,_,clt)
  | PC.TMetaConst(_,_,_,_,clt) | PC.TMetaErr(_,_,_,clt)
  | PC.TMetaExp(_,_,_,_,clt) | PC.TMetaIdExp(_,_,_,_,clt)
  | PC.TMetaLocalIdExp(_,_,_,_,clt)
  | PC.TMetaExpList(_,_,_,clt)
  | PC.TMetaId(_,_,_,clt)
  | PC.TMetaType(_,_,clt) | PC.TMetaInit(_,_,clt) | PC.TMetaStm(_,_,clt)
  | PC.TMetaStmList(_,_,clt)  | PC.TMetaFunc(_,_,_,clt)
  | PC.TMetaLocalFunc(_,_,_,clt)

  | PC.TWhen(clt) |  PC.TWhenTrue(clt) |  PC.TWhenFalse(clt)
  | PC.TAny(clt) | PC.TStrict(clt) | PC.TEllipsis(clt)
  (* | PC.TCircles(clt) | PC.TStars(clt) *)

  | PC.TWhy(clt) | PC.TDotDot(clt) | PC.TBang(clt) | PC.TOPar(clt)
  | PC.TCPar(clt)

  | PC.TOBrace(clt) | PC.TCBrace(clt) | PC.TOCro(clt) | PC.TCCro(clt)
  | PC.TOInit(clt)

  | PC.TPtrOp(clt)

  | PC.TEq(clt) | PC.TAssign(_,clt) | PC.TDot(clt) | PC.TComma(clt)
  | PC.TPtVirg(clt) ->
      if line_type clt = D.PLUS
      then PLUS
      else if only_plus then NOTPLUS
      else if line_type clt = D.CONTEXT then PLUS else NOTPLUS

  | PC.TOPar0(clt) | PC.TMid0(clt) | PC.TCPar0(clt)
  | PC.TOEllipsis(clt) | PC.TCEllipsis(clt)
  | PC.TPOEllipsis(clt) | PC.TPCEllipsis(clt) (* | PC.TOCircles(clt)
  | PC.TCCircles(clt) | PC.TOStars(clt) | PC.TCStars(clt) *) -> NOTPLUS
  | PC.TMetaPos(nm,_,_,_) -> NOTPLUS

  | _ -> SKIP

let get_clt (tok,_) =
  match tok with
    PC.Tchar(clt) | PC.Tshort(clt) | PC.Tint(clt) | PC.Tdouble(clt)
  | PC.Tfloat(clt) | PC.Tlong(clt) | PC.Tvoid(clt) | PC.Tstruct(clt)
  | PC.Tunion(clt) | PC.Tenum(clt) | PC.Tunsigned(clt) | PC.Tsigned(clt)
  | PC.Tstatic(clt)
  | PC.Tinline(clt) | PC.Tattr(_,clt) | PC.Tauto(clt) | PC.Tregister(clt)
  | PC.Textern(clt) | PC.Tconst(clt) | PC.Tvolatile(clt)

  | PC.TIncludeL(_,clt) | PC.TIncludeNL(_,clt) | PC.TDefine(clt,_)
  | PC.TDefineParam(clt,_,_,_) | PC.TMinusFile(_,clt) | PC.TPlusFile(_,clt)

  | PC.TInc(clt) | PC.TDec(clt)

  | PC.TIf(clt) | PC.TElse(clt) | PC.TWhile(clt) | PC.TFor(clt) | PC.TDo(clt)
  | PC.TSwitch(clt) | PC.TCase(clt) | PC.TDefault(clt) | PC.TReturn(clt)
  | PC.TBreak(clt) | PC.TContinue(clt) | PC.TGoto(clt) | PC.TIdent(_,clt)
  | PC.TTypeId(_,clt) | PC.TDeclarerId(_,clt) | PC.TIteratorId(_,clt)

  | PC.TSizeof(clt)

  | PC.TString(_,clt) | PC.TChar(_,clt) | PC.TFloat(_,clt) | PC.TInt(_,clt)

  | PC.TOrLog(clt) | PC.TAndLog(clt) | PC.TOr(clt) | PC.TXor(clt)
  | PC.TAnd (clt) | PC.TEqEq(clt) | PC.TNotEq(clt) | PC.TLogOp(_,clt)
  | PC.TShOp(_,clt) | PC.TPlus(clt) | PC.TMinus(clt) | PC.TMul(clt)
  | PC.TDmOp(_,clt) | PC.TTilde (clt)

  | PC.TMetaParam(_,_,clt) | PC.TMetaParamList(_,_,_,clt)
  | PC.TMetaConst(_,_,_,_,clt) | PC.TMetaErr(_,_,_,clt)
  | PC.TMetaExp(_,_,_,_,clt) | PC.TMetaIdExp(_,_,_,_,clt)
  | PC.TMetaLocalIdExp(_,_,_,_,clt)
  | PC.TMetaExpList(_,_,_,clt)
  | PC.TMetaId(_,_,_,clt)
  | PC.TMetaType(_,_,clt) | PC.TMetaInit(_,_,clt) | PC.TMetaStm(_,_,clt)
  | PC.TMetaStmList(_,_,clt)  | PC.TMetaFunc(_,_,_,clt)
  | PC.TMetaLocalFunc(_,_,_,clt) | PC.TMetaPos(_,_,_,clt)

  | PC.TWhen(clt) | PC.TWhenTrue(clt) | PC.TWhenFalse(clt) |
    PC.TAny(clt) | PC.TStrict(clt) | PC.TEllipsis(clt)
  (* | PC.TCircles(clt) | PC.TStars(clt) *)

  | PC.TWhy(clt) | PC.TDotDot(clt) | PC.TBang(clt) | PC.TOPar(clt)
  | PC.TCPar(clt)

  | PC.TOBrace(clt) | PC.TCBrace(clt) | PC.TOCro(clt) | PC.TCCro(clt)
  | PC.TOInit(clt)

  | PC.TPtrOp(clt)

  | PC.TEq(clt) | PC.TAssign(_,clt) | PC.TDot(clt) | PC.TComma(clt)
  | PC.TPtVirg(clt)

  | PC.TOPar0(clt) | PC.TMid0(clt) | PC.TCPar0(clt)
  | PC.TOEllipsis(clt) | PC.TCEllipsis(clt)
  | PC.TPOEllipsis(clt) | PC.TPCEllipsis(clt) (* | PC.TOCircles(clt)
  | PC.TCCircles(clt) | PC.TOStars(clt) | PC.TCStars(clt) *) -> clt

  | _ -> failwith "no clt"

let update_clt (tok,x) clt =
  match tok with
    PC.Tchar(_) -> (PC.Tchar(clt),x)
  | PC.Tshort(_) -> (PC.Tshort(clt),x)
  | PC.Tint(_) -> (PC.Tint(clt),x)
  | PC.Tdouble(_) -> (PC.Tdouble(clt),x)
  | PC.Tfloat(_) -> (PC.Tfloat(clt),x)
  | PC.Tlong(_) -> (PC.Tlong(clt),x)
  | PC.Tvoid(_) -> (PC.Tvoid(clt),x)
  | PC.Tstruct(_) -> (PC.Tstruct(clt),x)
  | PC.Tunion(_) -> (PC.Tunion(clt),x)
  | PC.Tenum(_) -> (PC.Tenum(clt),x)
  | PC.Tunsigned(_) -> (PC.Tunsigned(clt),x)
  | PC.Tsigned(_) -> (PC.Tsigned(clt),x)
  | PC.Tstatic(_) -> (PC.Tstatic(clt),x)
  | PC.Tinline(_) -> (PC.Tinline(clt),x)
  | PC.Ttypedef(_) -> (PC.Ttypedef(clt),x)
  | PC.Tattr(s,_) -> (PC.Tattr(s,clt),x)
  | PC.Tauto(_) -> (PC.Tauto(clt),x)
  | PC.Tregister(_) -> (PC.Tregister(clt),x)
  | PC.Textern(_) -> (PC.Textern(clt),x)
  | PC.Tconst(_) -> (PC.Tconst(clt),x)
  | PC.Tvolatile(_) -> (PC.Tvolatile(clt),x)

  | PC.TIncludeL(s,_) -> (PC.TIncludeL(s,clt),x)
  | PC.TIncludeNL(s,_) -> (PC.TIncludeNL(s,clt),x)
  | PC.TDefine(_,a) -> (PC.TDefine(clt,a),x)
  | PC.TDefineParam(_,a,b,c) -> (PC.TDefineParam(clt,a,b,c),x)
  | PC.TMinusFile(s,_) -> (PC.TMinusFile(s,clt),x)
  | PC.TPlusFile(s,_) -> (PC.TPlusFile(s,clt),x)

  | PC.TInc(_) -> (PC.TInc(clt),x)
  | PC.TDec(_) -> (PC.TDec(clt),x)

  | PC.TIf(_) -> (PC.TIf(clt),x)
  | PC.TElse(_) -> (PC.TElse(clt),x)
  | PC.TWhile(_) -> (PC.TWhile(clt),x)
  | PC.TFor(_) -> (PC.TFor(clt),x)
  | PC.TDo(_) -> (PC.TDo(clt),x)
  | PC.TSwitch(_) -> (PC.TSwitch(clt),x)
  | PC.TCase(_) -> (PC.TCase(clt),x)
  | PC.TDefault(_) -> (PC.TDefault(clt),x)
  | PC.TReturn(_) -> (PC.TReturn(clt),x)
  | PC.TBreak(_) -> (PC.TBreak(clt),x)
  | PC.TContinue(_) -> (PC.TContinue(clt),x)
  | PC.TGoto(_) -> (PC.TGoto(clt),x)
  | PC.TIdent(s,_) -> (PC.TIdent(s,clt),x)
  | PC.TTypeId(s,_) -> (PC.TTypeId(s,clt),x)
  | PC.TDeclarerId(s,_) -> (PC.TDeclarerId(s,clt),x)
  | PC.TIteratorId(s,_) -> (PC.TIteratorId(s,clt),x)

  | PC.TSizeof(_) -> (PC.TSizeof(clt),x)

  | PC.TString(s,_) -> (PC.TString(s,clt),x)
  | PC.TChar(s,_) -> (PC.TChar(s,clt),x)
  | PC.TFloat(s,_) -> (PC.TFloat(s,clt),x)
  | PC.TInt(s,_) -> (PC.TInt(s,clt),x)

  | PC.TOrLog(_) -> (PC.TOrLog(clt),x)
  | PC.TAndLog(_) -> (PC.TAndLog(clt),x)
  | PC.TOr(_) -> (PC.TOr(clt),x)
  | PC.TXor(_) -> (PC.TXor(clt),x)
  | PC.TAnd (_) -> (PC.TAnd (clt),x)
  | PC.TEqEq(_) -> (PC.TEqEq(clt),x)
  | PC.TNotEq(_) -> (PC.TNotEq(clt),x)
  | PC.TLogOp(op,_) -> (PC.TLogOp(op,clt),x)
  | PC.TShOp(op,_) -> (PC.TShOp(op,clt),x)
  | PC.TPlus(_) -> (PC.TPlus(clt),x)
  | PC.TMinus(_) -> (PC.TMinus(clt),x)
  | PC.TMul(_) -> (PC.TMul(clt),x)
  | PC.TDmOp(op,_) -> (PC.TDmOp(op,clt),x)
  | PC.TTilde (_) -> (PC.TTilde (clt),x)

  | PC.TMetaParam(a,b,_) -> (PC.TMetaParam(a,b,clt),x)
  | PC.TMetaParamList(a,b,c,_) -> (PC.TMetaParamList(a,b,c,clt),x)
  | PC.TMetaConst(a,b,c,d,_) -> (PC.TMetaConst(a,b,c,d,clt),x)
  | PC.TMetaErr(a,b,c,_) -> (PC.TMetaErr(a,b,c,clt),x)
  | PC.TMetaExp(a,b,c,d,_) -> (PC.TMetaExp(a,b,c,d,clt),x)
  | PC.TMetaIdExp(a,b,c,d,_) -> (PC.TMetaIdExp(a,b,c,d,clt),x)
  | PC.TMetaLocalIdExp(a,b,c,d,_) -> (PC.TMetaLocalIdExp(a,b,c,d,clt),x)
  | PC.TMetaExpList(a,b,c,_) -> (PC.TMetaExpList(a,b,c,clt),x)
  | PC.TMetaId(a,b,c,_)    -> (PC.TMetaId(a,b,c,clt),x)
  | PC.TMetaType(a,b,_)    -> (PC.TMetaType(a,b,clt),x)
  | PC.TMetaInit(a,b,_)    -> (PC.TMetaInit(a,b,clt),x)
  | PC.TMetaStm(a,b,_)   -> (PC.TMetaStm(a,b,clt),x)
  | PC.TMetaStmList(a,b,_)   -> (PC.TMetaStmList(a,b,clt),x)
  | PC.TMetaFunc(a,b,c,_)  -> (PC.TMetaFunc(a,b,c,clt),x)
  | PC.TMetaLocalFunc(a,b,c,_) -> (PC.TMetaLocalFunc(a,b,c,clt),x)

  | PC.TWhen(_) -> (PC.TWhen(clt),x)
  | PC.TWhenTrue(_) -> (PC.TWhenTrue(clt),x)
  | PC.TWhenFalse(_) -> (PC.TWhenFalse(clt),x)
  | PC.TAny(_) -> (PC.TAny(clt),x)
  | PC.TStrict(_) -> (PC.TStrict(clt),x)
  | PC.TEllipsis(_) -> (PC.TEllipsis(clt),x)
(*
  | PC.TCircles(_)  -> (PC.TCircles(clt),x)
  | PC.TStars(_)    -> (PC.TStars(clt),x)
*)

  | PC.TOEllipsis(_) -> (PC.TOEllipsis(clt),x)
  | PC.TCEllipsis(_) -> (PC.TCEllipsis(clt),x)
  | PC.TPOEllipsis(_) -> (PC.TPOEllipsis(clt),x)
  | PC.TPCEllipsis(_) -> (PC.TPCEllipsis(clt),x)
(*
  | PC.TOCircles(_)  -> (PC.TOCircles(clt),x)
  | PC.TCCircles(_)  -> (PC.TCCircles(clt),x)
  | PC.TOStars(_)    -> (PC.TOStars(clt),x)
  | PC.TCStars(_)    -> (PC.TCStars(clt),x)
*)

  | PC.TWhy(_)   -> (PC.TWhy(clt),x)
  | PC.TDotDot(_)   -> (PC.TDotDot(clt),x)
  | PC.TBang(_)  -> (PC.TBang(clt),x)
  | PC.TOPar(_)  -> (PC.TOPar(clt),x)
  | PC.TOPar0(_) -> (PC.TOPar0(clt),x)
  | PC.TMid0(_)  -> (PC.TMid0(clt),x)
  | PC.TCPar(_)  -> (PC.TCPar(clt),x)
  | PC.TCPar0(_) -> (PC.TCPar0(clt),x)

  | PC.TOBrace(_) -> (PC.TOBrace(clt),x)
  | PC.TCBrace(_) -> (PC.TCBrace(clt),x)
  | PC.TOCro(_) -> (PC.TOCro(clt),x)
  | PC.TCCro(_) -> (PC.TCCro(clt),x)
  | PC.TOInit(_) -> (PC.TOInit(clt),x)

  | PC.TPtrOp(_) -> (PC.TPtrOp(clt),x)

  | PC.TEq(_) -> (PC.TEq(clt),x)
  | PC.TAssign(s,_) -> (PC.TAssign(s,clt),x)
  | PC.TDot(_) -> (PC.TDot(clt),x)
  | PC.TComma(_) -> (PC.TComma(clt),x)
  | PC.TPtVirg(_) -> (PC.TPtVirg(clt),x)

  | PC.TLineEnd(_) -> (PC.TLineEnd(clt),x)
  | PC.TFunDecl(_) -> (PC.TFunDecl(clt),x)

  | _ -> failwith "no clt"


(* ----------------------------------------------------------------------- *)

let make_name prefix ln = Printf.sprintf "%s starting on line %d" prefix ln

(* ----------------------------------------------------------------------- *)
(* Read tokens *)

let wrap_lexbuf_info lexbuf =
  (Lexing.lexeme lexbuf, Lexing.lexeme_start lexbuf)

let tokens_all_full token table file get_ats lexbuf end_markers :
    (bool * ((PC.token * (string * (int * int) * (int * int))) list)) =
  try
    let rec aux () =
      let result = token lexbuf in
      let info = (Lexing.lexeme lexbuf,
                  (table.(Lexing.lexeme_start lexbuf)),
                  (Lexing.lexeme_start lexbuf, Lexing.lexeme_end lexbuf)) in
      if result = PC.EOF
      then
	if get_ats
	then failwith "unexpected end of file in a metavariable declaration"
	else (false,[(result,info)])
      else if List.mem result end_markers
      then (true,[(result,info)])
      else
	let (more,rest) = aux() in
	(more,(result, info)::rest)
    in aux ()
  with
    e -> pr2 (Common.error_message file (wrap_lexbuf_info lexbuf) ); raise e

let tokens_all table file get_ats lexbuf end_markers :
    (bool * ((PC.token * (string * (int * int) * (int * int))) list)) =
  tokens_all_full Lexer_cocci.token table file get_ats lexbuf end_markers

let tokens_script_all table file get_ats lexbuf end_markers :
    (bool * ((PC.token * (string * (int * int) * (int * int))) list)) =
  tokens_all_full Lexer_script.token table file get_ats lexbuf end_markers

(* ----------------------------------------------------------------------- *)
(* Split tokens into minus and plus fragments *)

let split t clt =
  let (d,_,_,_,_,_,_,_) = clt in
  match d with
    D.MINUS | D.OPTMINUS | D.UNIQUEMINUS -> ([t],[])
  | D.PLUS -> ([],[t])
  | D.CONTEXT | D.UNIQUE | D.OPT -> ([t],[t])

let split_token ((tok,_) as t) =
  match tok with
    PC.TIdentifier | PC.TConstant | PC.TExpression | PC.TIdExpression
  | PC.TStatement | PC.TPosition | PC.TPosAny | PC.TInitialiser
  | PC.TFunction | PC.TTypedef | PC.TDeclarer | PC.TIterator | PC.TName
  | PC.TType | PC.TParameter | PC.TLocal | PC.Tlist | PC.TFresh
  | PC.TCppConcatOp | PC.TPure
  | PC.TContext | PC.TRuleName(_) | PC.TUsing | PC.TVirtual | PC.TDisable
  | PC.TExtends | PC.TPathIsoFile(_)
  | PC.TDepends | PC.TOn | PC.TEver | PC.TNever | PC.TExists | PC.TForall
  | PC.TError | PC.TWords | PC.TGenerated | PC.TNothing -> ([t],[t])

  | PC.Tchar(clt) | PC.Tshort(clt) | PC.Tint(clt) | PC.Tdouble(clt)
  | PC.Tfloat(clt) | PC.Tlong(clt) | PC.Tvoid(clt) | PC.Tstruct(clt)
  | PC.Tunion(clt) | PC.Tenum(clt) | PC.Tunsigned(clt) | PC.Tsigned(clt)
  | PC.Tstatic(clt) | PC.Tauto(clt) | PC.Tregister(clt) | PC.Textern(clt)
  | PC.Tinline(clt) | PC.Ttypedef(clt) | PC.Tattr(_,clt)
  | PC.Tconst(clt) | PC.Tvolatile(clt) -> split t clt

  | PC.TPragma(s,_) -> ([],[t]) (* only allowed in + *)
  | PC.TPlusFile(s,clt) | PC.TMinusFile(s,clt)
  | PC.TIncludeL(s,clt) | PC.TIncludeNL(s,clt) ->
      split t clt
  | PC.TDefine(clt,_) | PC.TDefineParam(clt,_,_,_) -> split t clt

  | PC.TIf(clt) | PC.TElse(clt)  | PC.TWhile(clt) | PC.TFor(clt) | PC.TDo(clt)
  | PC.TSwitch(clt) | PC.TCase(clt) | PC.TDefault(clt)
  | PC.TSizeof(clt)
  | PC.TReturn(clt) | PC.TBreak(clt) | PC.TContinue(clt) | PC.TGoto(clt)
  | PC.TIdent(_,clt)
  | PC.TTypeId(_,clt) | PC.TDeclarerId(_,clt) | PC.TIteratorId(_,clt)
  | PC.TMetaConst(_,_,_,_,clt) | PC.TMetaExp(_,_,_,_,clt)
  | PC.TMetaIdExp(_,_,_,_,clt) | PC.TMetaLocalIdExp(_,_,_,_,clt)
  | PC.TMetaExpList(_,_,_,clt)
  | PC.TMetaParam(_,_,clt) | PC.TMetaParamList(_,_,_,clt)
  | PC.TMetaId(_,_,_,clt) | PC.TMetaType(_,_,clt) | PC.TMetaInit(_,_,clt)
  | PC.TMetaStm(_,_,clt) | PC.TMetaStmList(_,_,clt) | PC.TMetaErr(_,_,_,clt)
  | PC.TMetaFunc(_,_,_,clt) | PC.TMetaLocalFunc(_,_,_,clt)
  | PC.TMetaDeclarer(_,_,_,clt) | PC.TMetaIterator(_,_,_,clt) -> split t clt
  | PC.TMPtVirg | PC.TArob | PC.TArobArob | PC.TScript
  | PC.TInitialize | PC.TFinalize -> ([t],[t])
  | PC.TPArob | PC.TMetaPos(_,_,_,_) -> ([t],[])

  | PC.TFunDecl(clt)
  | PC.TWhen(clt) | PC.TWhenTrue(clt) | PC.TWhenFalse(clt)
  | PC.TAny(clt) | PC.TStrict(clt) | PC.TLineEnd(clt)
  | PC.TEllipsis(clt) (* | PC.TCircles(clt) | PC.TStars(clt) *) -> split t clt

  | PC.TOEllipsis(_) | PC.TCEllipsis(_) (* clt must be context *)
  | PC.TPOEllipsis(_) | PC.TPCEllipsis(_) (* clt must be context *)
(*
  | PC.TOCircles(_) | PC.TCCircles(_)   (* clt must be context *)
  | PC.TOStars(_) | PC.TCStars(_)       (* clt must be context *)
*)
  | PC.TBang0 | PC.TPlus0 | PC.TWhy0 ->
      ([t],[t])

  | PC.TWhy(clt)  | PC.TDotDot(clt)
  | PC.TBang(clt) | PC.TOPar(clt) | PC.TOPar0(clt)
  | PC.TMid0(clt) | PC.TCPar(clt) | PC.TCPar0(clt) -> split t clt

  | PC.TInc(clt) | PC.TDec(clt) -> split t clt

  | PC.TString(_,clt) | PC.TChar(_,clt) | PC.TFloat(_,clt) | PC.TInt(_,clt) ->
      split t clt

  | PC.TOrLog(clt) | PC.TAndLog(clt) | PC.TOr(clt) | PC.TXor(clt)
  | PC.TAnd (clt) | PC.TEqEq(clt) | PC.TNotEq(clt) | PC.TLogOp(_,clt)
  | PC.TShOp(_,clt) | PC.TPlus(clt) | PC.TMinus(clt) | PC.TMul(clt)
  | PC.TDmOp(_,clt) | PC.TTilde (clt) -> split t clt

  | PC.TOBrace(clt) | PC.TCBrace(clt) | PC.TOInit(clt) -> split t clt
  | PC.TOCro(clt) | PC.TCCro(clt) -> split t clt

  | PC.TPtrOp(clt) -> split t clt

  | PC.TEq(clt) | PC.TAssign(_,clt) | PC.TDot(clt) | PC.TComma(clt)
  | PC.TPtVirg(clt) -> split t clt

  | PC.EOF | PC.TInvalid -> ([t],[t])

  | PC.TIso | PC.TRightIso
  | PC.TIsoExpression | PC.TIsoStatement | PC.TIsoDeclaration | PC.TIsoType
  | PC.TIsoTopLevel | PC.TIsoArgExpression | PC.TIsoTestExpression ->
      failwith "unexpected tokens"
  | PC.TScriptData s -> ([t],[t])

let split_token_stream tokens =
  let rec loop = function
      [] -> ([],[])
    | token::tokens ->
	let (minus,plus) = split_token token in
	let (minus_stream,plus_stream) = loop tokens in
	(minus@minus_stream,plus@plus_stream) in
  loop tokens

(* ----------------------------------------------------------------------- *)
(* Find function names *)
(* This addresses a shift-reduce problem in the parser, allowing us to
distinguish a function declaration from a function call even if the latter
has no return type.  Undoubtedly, this is not very nice, but it doesn't
seem very convenient to refactor the grammar to get around the problem. *)

let rec find_function_names = function
    [] -> []
  | ((PC.TIdent(_,clt),info) as t1) :: ((PC.TOPar(_),_) as t2) :: rest
  | ((PC.TMetaId(_,_,_,clt),info) as t1) :: ((PC.TOPar(_),_) as t2) :: rest
  | ((PC.TMetaFunc(_,_,_,clt),info) as t1) :: ((PC.TOPar(_),_) as t2) :: rest
  | ((PC.TMetaLocalFunc(_,_,_,clt),info) as t1)::((PC.TOPar(_),_) as t2)::rest
    ->
      let rec skip level = function
	  [] -> ([],false,[])
	| ((PC.TCPar(_),_) as t)::rest ->
	    let level = level - 1 in
	    if level = 0
	    then ([t],true,rest)
	    else let (pre,found,post) = skip level rest in (t::pre,found,post)
	| ((PC.TOPar(_),_) as t)::rest ->
	    let level = level + 1 in
	    let (pre,found,post) = skip level rest in (t::pre,found,post)
	| ((PC.TArobArob,_) as t)::rest
	| ((PC.TArob,_) as t)::rest
	| ((PC.EOF,_) as t)::rest -> ([t],false,rest)
	| t::rest ->
      	    let (pre,found,post) = skip level rest in (t::pre,found,post) in
      let (pre,found,post) = skip 1 rest in
      (match (found,post) with
	(true,((PC.TOBrace(_),_) as t3)::rest) ->
	  (PC.TFunDecl(clt),info) :: t1 :: t2 :: pre @
	  t3 :: (find_function_names rest)
      |	_ -> t1 :: t2 :: pre @ find_function_names post)
  | t :: rest -> t :: find_function_names rest

(* ----------------------------------------------------------------------- *)
(* an attribute is an identifier that preceeds another identifier and
   begins with __ *)

let rec detect_attr l =
  let is_id = function
      (PC.TIdent(_,_),_) | (PC.TMetaId(_,_,_,_),_) | (PC.TMetaFunc(_,_,_,_),_)
    | (PC.TMetaLocalFunc(_,_,_,_),_) -> true
    | _ -> false in
  let rec loop = function
      [] -> []
    | [x] -> [x]
    | ((PC.TIdent(nm,clt),info) as t1)::id::rest when is_id id ->
	if String.length nm > 2 && String.sub nm 0 2 = "__"
	then (PC.Tattr(nm,clt),info)::(loop (id::rest))
	else t1::(loop (id::rest))
    | x::xs -> x::(loop xs) in
  loop l

(* ----------------------------------------------------------------------- *)
(* Look for variable declarations where the name is a typedef name.
We assume that C code does not contain a multiplication as a top-level
statement. *)

(* bug: once a type, always a type, even if the same name is later intended
   to be used as a real identifier *)
let detect_types in_meta_decls l =
  let is_delim infn = function
      (PC.TOEllipsis(_),_) (* | (PC.TOCircles(_),_) | (PC.TOStars(_),_) *)
    | (PC.TPOEllipsis(_),_) (* | (PC.TOCircles(_),_) | (PC.TOStars(_),_) *)
    | (PC.TEllipsis(_),_) (* | (PC.TCircles(_),_) | (PC.TStars(_),_) *)
    | (PC.TPtVirg(_),_) | (PC.TOBrace(_),_) | (PC.TOInit(_),_)
    | (PC.TCBrace(_),_)
    | (PC.TPure,_) | (PC.TContext,_)
    | (PC.Tstatic(_),_) | (PC.Textern(_),_)
    | (PC.Tinline(_),_) | (PC.Ttypedef(_),_) | (PC.Tattr(_),_) -> true
    | (PC.TComma(_),_) when infn > 0 or in_meta_decls -> true
    | (PC.TDotDot(_),_) when in_meta_decls -> true
    | _ -> false in
  let is_choices_delim = function
      (PC.TOBrace(_),_) | (PC.TComma(_),_) -> true | _ -> false in
  let is_id = function
      (PC.TIdent(_,_),_) | (PC.TMetaId(_,_,_,_),_) | (PC.TMetaFunc(_,_,_,_),_)
    | (PC.TMetaLocalFunc(_,_,_,_),_) -> true
    | (PC.TMetaParam(_,_,_),_)
    | (PC.TMetaParamList(_,_,_,_),_)
    | (PC.TMetaConst(_,_,_,_,_),_)
    | (PC.TMetaErr(_,_,_,_),_)
    | (PC.TMetaExp(_,_,_,_,_),_)
    | (PC.TMetaIdExp(_,_,_,_,_),_)
    | (PC.TMetaLocalIdExp(_,_,_,_,_),_)
    | (PC.TMetaExpList(_,_,_,_),_)
    | (PC.TMetaType(_,_,_),_)
    | (PC.TMetaInit(_,_,_),_)
    | (PC.TMetaStm(_,_,_),_)
    | (PC.TMetaStmList(_,_,_),_)
    | (PC.TMetaPos(_,_,_,_),_) -> in_meta_decls
    | _ -> false in
  let redo_id ident clt v =
    !Data.add_type_name ident;
    (PC.TTypeId(ident,clt),v) in
  let rec loop start infn type_names = function
      (* infn: 0 means not in a function header
	 > 0 means in a function header, after infn - 1 unmatched open parens*)
      [] -> []
    | ((PC.TOBrace(clt),v)::_) as all when in_meta_decls ->
	collect_choices type_names all (* never a function header *)
    | delim::(PC.TIdent(ident,clt),v)::((PC.TMul(_),_) as x)::rest
      when is_delim infn delim ->
	let newid = redo_id ident clt v in
	delim::newid::x::(loop false infn (ident::type_names) rest)
    | delim::(PC.TIdent(ident,clt),v)::id::rest
      when is_delim infn delim && is_id id ->
	let newid = redo_id ident clt v in
	delim::newid::id::(loop false infn (ident::type_names) rest)
    | ((PC.TFunDecl(_),_) as fn)::rest ->
	fn::(loop false 1 type_names rest)
    | ((PC.TOPar(_),_) as lp)::rest when infn > 0 ->
	lp::(loop false (infn + 1) type_names rest)
    | ((PC.TCPar(_),_) as rp)::rest when infn > 0 ->
	if infn - 1 = 1
	then rp::(loop false 0 type_names rest) (* 0 means not in fn header *)
	else rp::(loop false (infn - 1) type_names rest)
    | (PC.TIdent(ident,clt),v)::((PC.TMul(_),_) as x)::rest when start ->
	let newid = redo_id ident clt v in
	newid::x::(loop false infn (ident::type_names) rest)
    | (PC.TIdent(ident,clt),v)::id::rest when start && is_id id ->
	let newid = redo_id ident clt v in
	newid::id::(loop false infn (ident::type_names) rest)
    | (PC.TIdent(ident,clt),v)::rest when List.mem ident type_names ->
	(PC.TTypeId(ident,clt),v)::(loop false infn type_names rest)
    | ((PC.TIdent(ident,clt),v) as x)::rest ->
	x::(loop false infn type_names rest)
    | x::rest -> x::(loop false infn type_names rest)
  and collect_choices type_names = function
      [] -> [] (* should happen, but let the parser detect that *)
    | (PC.TCBrace(clt),v)::rest ->
	(PC.TCBrace(clt),v)::(loop false 0 type_names rest)
    | delim::(PC.TIdent(ident,clt),v)::rest
      when is_choices_delim delim ->
	let newid = redo_id ident clt v in
	delim::newid::(collect_choices (ident::type_names) rest)
    | x::rest -> x::(collect_choices type_names rest) in
  loop true 0 [] l


(* ----------------------------------------------------------------------- *)
(* Insert TLineEnd tokens at the end of a line that contains a WHEN.
   WHEN is restricted to a single line, to avoid ambiguity in eg:
   ... WHEN != x
   +3 *)

let token2line (tok,_) =
  match tok with
    PC.Tchar(clt) | PC.Tshort(clt) | PC.Tint(clt) | PC.Tdouble(clt)
  | PC.Tfloat(clt) | PC.Tlong(clt) | PC.Tvoid(clt) | PC.Tstruct(clt)
  | PC.Tunion(clt) | PC.Tenum(clt) | PC.Tunsigned(clt) | PC.Tsigned(clt)
  | PC.Tstatic(clt) | PC.Tauto(clt) | PC.Tregister(clt) | PC.Textern(clt)
  | PC.Tinline(clt) | PC.Ttypedef(clt) | PC.Tattr(_,clt) | PC.Tconst(clt)
  | PC.Tvolatile(clt)

  | PC.TInc(clt) | PC.TDec(clt)

  | PC.TIf(clt) | PC.TElse(clt) | PC.TWhile(clt) | PC.TFor(clt) | PC.TDo(clt)
  | PC.TSwitch (clt) | PC.TCase (clt) | PC.TDefault (clt) | PC.TSizeof (clt)
  | PC.TReturn(clt) | PC.TBreak(clt) | PC.TContinue(clt) | PC.TGoto(clt)
  | PC.TIdent(_,clt)
  | PC.TTypeId(_,clt) | PC.TDeclarerId(_,clt) | PC.TIteratorId(_,clt)
  | PC.TMetaDeclarer(_,_,_,clt) | PC.TMetaIterator(_,_,_,clt)

  | PC.TString(_,clt) | PC.TChar(_,clt) | PC.TFloat(_,clt) | PC.TInt(_,clt)

  | PC.TOrLog(clt) | PC.TAndLog(clt) | PC.TOr(clt) | PC.TXor(clt)
  | PC.TAnd (clt) | PC.TEqEq(clt) | PC.TNotEq(clt) | PC.TLogOp(_,clt)
  | PC.TShOp(_,clt) | PC.TPlus(clt) | PC.TMinus(clt) | PC.TMul(clt)
  | PC.TDmOp(_,clt) | PC.TTilde (clt)

  | PC.TMetaParam(_,_,clt) | PC.TMetaParamList(_,_,_,clt)
  | PC.TMetaConst(_,_,_,_,clt) | PC.TMetaExp(_,_,_,_,clt)
  | PC.TMetaIdExp(_,_,_,_,clt) | PC.TMetaLocalIdExp(_,_,_,_,clt)
  | PC.TMetaExpList(_,_,_,clt)
  | PC.TMetaId(_,_,_,clt) | PC.TMetaType(_,_,clt) | PC.TMetaInit(_,_,clt)
  | PC.TMetaStm(_,_,clt) | PC.TMetaStmList(_,_,clt) | PC.TMetaFunc(_,_,_,clt)
  | PC.TMetaLocalFunc(_,_,_,clt) | PC.TMetaPos(_,_,_,clt)

  | PC.TFunDecl(clt)
  | PC.TWhen(clt) | PC.TWhenTrue(clt) | PC.TWhenFalse(clt)
  | PC.TAny(clt) | PC.TStrict(clt) | PC.TEllipsis(clt)
  (* | PC.TCircles(clt) | PC.TStars(clt) *)

  | PC.TOEllipsis(clt) | PC.TCEllipsis(clt)
  | PC.TPOEllipsis(clt) | PC.TPCEllipsis(clt) (*| PC.TOCircles(clt)
  | PC.TCCircles(clt) | PC.TOStars(clt) | PC.TCStars(clt) *)

  | PC.TWhy(clt) | PC.TDotDot(clt) | PC.TBang(clt) | PC.TOPar(clt)
  | PC.TOPar0(clt) | PC.TMid0(clt) | PC.TCPar(clt)
  | PC.TCPar0(clt)

  | PC.TOBrace(clt) | PC.TCBrace(clt) | PC.TOCro(clt) | PC.TCCro(clt)
  | PC.TOInit(clt)

  | PC.TPtrOp(clt)

  | PC.TDefine(clt,_) | PC.TDefineParam(clt,_,_,_)
  | PC.TIncludeL(_,clt) | PC.TIncludeNL(_,clt)

  | PC.TEq(clt) | PC.TAssign(_,clt) | PC.TDot(clt) | PC.TComma(clt)
  | PC.TPtVirg(clt) ->
      let (_,line,_,_,_,_,_,_) = clt in Some line

  | _ -> None

let rec insert_line_end = function
    [] -> []
  | (((PC.TWhen(clt),q) as x)::xs) ->
      x::(find_line_end true (token2line x) clt q xs)
  | (((PC.TDefine(clt,_),q) as x)::xs)
  | (((PC.TDefineParam(clt,_,_,_),q) as x)::xs) ->
      x::(find_line_end false (token2line x) clt q xs)
  | x::xs -> x::(insert_line_end xs)

and find_line_end inwhen line clt q = function
    (* don't know what 2nd component should be so just use the info of
       the When.  Also inherit - of when, if any *)
    [] -> [(PC.TLineEnd(clt),q)]
  | ((PC.TIdent("strict",clt),a) as x)::xs when token2line x = line ->
      (PC.TStrict(clt),a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TIdent("STRICT",clt),a) as x)::xs when token2line x = line ->
      (PC.TStrict(clt),a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TIdent("any",clt),a) as x)::xs when token2line x = line ->
      (PC.TAny(clt),a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TIdent("ANY",clt),a) as x)::xs when token2line x = line ->
      (PC.TAny(clt),a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TIdent("forall",clt),a) as x)::xs when token2line x = line ->
      (PC.TForall,a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TIdent("exists",clt),a) as x)::xs when token2line x = line ->
      (PC.TExists,a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TComma(clt),a) as x)::xs when token2line x = line ->
      (PC.TComma(clt),a) :: (find_line_end inwhen line clt q xs)
  | ((PC.TPArob,a) as x)::xs -> (* no line #, just assume on the same line *)
      x :: (find_line_end inwhen line clt q xs)
  | x::xs when token2line x = line -> x :: (find_line_end inwhen line clt q xs)
  | xs -> (PC.TLineEnd(clt),q)::(insert_line_end xs)

let rec translate_when_true_false = function
    [] -> []
  | (PC.TWhen(clt),q)::((PC.TNotEq(_),_) as x)::(PC.TIdent("true",_),_)::xs ->
      (PC.TWhenTrue(clt),q)::x::(translate_when_true_false xs)
  | (PC.TWhen(clt),q)::((PC.TNotEq(_),_) as x)::(PC.TIdent("false",_),_)::xs ->
      (PC.TWhenFalse(clt),q)::x::(translate_when_true_false xs)
  | x::xs -> x :: (translate_when_true_false xs)

(* ----------------------------------------------------------------------- *)

let check_parentheses tokens =
  let clt2line (_,line,_,_,_,_,_,_) = line in
  let rec loop seen_open = function
      [] -> tokens
    | (PC.TOPar(clt),q) :: rest
    | (PC.TDefineParam(clt,_,_,_),q) :: rest ->
	loop (Common.Left (clt2line clt) :: seen_open) rest
    | (PC.TOPar0(clt),q) :: rest ->
	loop (Common.Right (clt2line clt) :: seen_open) rest
    | (PC.TCPar(clt),q) :: rest ->
	(match seen_open with
	  [] ->
	    failwith
	      (Printf.sprintf
		 "unexpected close parenthesis in line %d\n" (clt2line clt))
	| Common.Left _ :: seen_open -> loop seen_open rest
	| Common.Right open_line :: _ -> 
	    failwith
	      (Printf.sprintf
		 "disjunction parenthesis in line %d column 0 matched to normal parenthesis on line %d\n" open_line (clt2line clt)))
    | (PC.TCPar0(clt),q) :: rest ->
	(match seen_open with
	  [] ->
	    failwith
	      (Printf.sprintf
		 "unexpected close parenthesis in line %d\n" (clt2line clt))
	| Common.Right _ :: seen_open -> loop seen_open rest
	| Common.Left open_line :: _ -> 
	    failwith
	      (Printf.sprintf
		 "normal parenthesis in line %d matched to disjunction parenthesis on line %d column 0\n" open_line (clt2line clt)))
    | x::rest -> loop seen_open rest in
  loop [] tokens

(* ----------------------------------------------------------------------- *)
(* top level initializers: a sequence of braces followed by a dot *)

let find_top_init tokens =
  match tokens with
    (PC.TOBrace(clt),q) :: rest ->
      let rec dot_start acc = function
	  ((PC.TOBrace(_),_) as x) :: rest ->
	    dot_start (x::acc) rest
	| ((PC.TDot(_),_) :: rest) as x ->
	    Some ((PC.TOInit(clt),q) :: (List.rev acc) @ x)
	| l -> None in
      let rec comma_end acc = function
	  ((PC.TCBrace(_),_) as x) :: rest ->
	    comma_end (x::acc) rest
	| ((PC.TComma(_),_) :: rest) as x ->
	    Some ((PC.TOInit(clt),q) :: (List.rev x) @ acc)
	| l -> None in
      (match dot_start [] rest with
	Some x -> x
      |	None ->
	  (match List.rev rest with
	    (* not super sure what this does, but EOF, @, and @@ should be
	       the same, markind the end of a rule *)
	    ((PC.EOF,_) as x)::rest | ((PC.TArob,_) as x)::rest
	  | ((PC.TArobArob,_) as x)::rest ->
	      (match comma_end [x] rest with
		Some x -> x
	      | None -> tokens)
	  | _ ->
	      failwith "unexpected empty token list"))
  | _ -> tokens

(* ----------------------------------------------------------------------- *)
(* Integrate pragmas into some adjacent token.  + tokens are preferred.  Dots
are not allowed. *)

let rec collect_all_pragmas collected = function
    (PC.TPragma(s,(_,line,logical_line,offset,col,_,_,pos)),_)::rest ->
      let i =
	{ Ast0.line_start = line; Ast0.line_end = line;
	  Ast0.logical_start = logical_line; Ast0.logical_end = logical_line;
	  Ast0.column = col; Ast0.offset = offset; } in
      collect_all_pragmas ((s,i)::collected) rest
  | l -> (List.rev collected,l)

let rec collect_pass = function
    [] -> ([],[])
  | x::xs ->
      match plus_attachable false x with
	SKIP ->
	  let (pass,rest) = collect_pass xs in
	  (x::pass,rest)
      |	_ -> ([],x::xs)

let plus_attach strict = function
    None -> NOTPLUS
  | Some x -> plus_attachable strict x

let add_bef = function Some x -> [x] | None -> []

(*skips should be things like line end
skips is things before pragmas that can't be attached to, pass is things
after.  pass is used immediately.  skips accumulates. *)
let rec process_pragmas bef skips = function
    [] -> add_bef bef @ List.rev skips
  | ((PC.TPragma(s,i),_)::_) as l ->
      let (pragmas,rest) = collect_all_pragmas [] l in
      let (pass,rest0) = collect_pass rest in
      let (next,rest) =
	match rest0 with [] -> (None,[]) | next::rest -> (Some next,rest) in
      (match (bef,plus_attach true bef,next,plus_attach true next) with
	(Some bef,PLUS,_,_) ->
	  let (a,b,c,d,e,strbef,straft,pos) = get_clt bef in
	  (update_clt bef (a,b,c,d,e,strbef,pragmas,pos))::List.rev skips@
	  pass@process_pragmas None [] rest0
      |	(_,_,Some next,PLUS) ->
	  let (a,b,c,d,e,strbef,straft,pos) = get_clt next in
	  (add_bef bef) @ List.rev skips @ pass @
	  (process_pragmas
	     (Some (update_clt next (a,b,c,d,e,pragmas,straft,pos)))
	     [] rest)
      |	_ ->
	  (match (bef,plus_attach false bef,next,plus_attach false next) with
	    (Some bef,PLUS,_,_) ->
	      let (a,b,c,d,e,strbef,straft,pos) = get_clt bef in
	      (update_clt bef (a,b,c,d,e,strbef,pragmas,pos))::List.rev skips@
	      pass@process_pragmas None [] rest0
	  | (_,_,Some next,PLUS) ->
	      let (a,b,c,d,e,strbef,straft,pos) = get_clt next in
	      (add_bef bef) @ List.rev skips @ pass @
	      (process_pragmas
		 (Some (update_clt next (a,b,c,d,e,pragmas,straft,pos)))
		 [] rest)
	  | _ -> failwith "nothing to attach pragma to"))
  | x::xs ->
      (match plus_attachable false x with
	SKIP -> process_pragmas bef (x::skips) xs
      |	_ -> (add_bef bef) @ List.rev skips @ (process_pragmas (Some x) [] xs))

(* ----------------------------------------------------------------------- *)
(* Drop ... ... .  This is only allowed in + code, and arises when there is
some - code between the ... *)
(* drop whens as well - they serve no purpose in + code and they cause
problems for drop_double_dots *)

let rec drop_when = function
    [] -> []
  | (PC.TWhen(clt),info)::xs ->
      let rec loop = function
	  [] -> []
	| (PC.TLineEnd(_),info)::xs -> drop_when xs
	| x::xs -> loop xs in
      loop xs
  | x::xs -> x::drop_when xs

(* instead of dropping the double dots, we put TNothing in between them.
these vanish after the parser, but keeping all the ...s in the + code makes
it easier to align the + and - code in context_neg and in preparation for the
isomorphisms.  This shouldn't matter because the context code of the +
slice is mostly ignored anyway *)
let minus_to_nothing l =
  (* for cases like | <..., which may or may not arise from removing minus
     code, depending on whether <... is a statement or expression *)
  let is_minus tok =
    try
      let (d,_,_,_,_,_,_,_) = get_clt tok in
      (match d with
	D.MINUS | D.OPTMINUS | D.UNIQUEMINUS -> true
      | D.PLUS -> false
      | D.CONTEXT | D.UNIQUE | D.OPT -> false)
    with _ -> false in
  let rec minus_loop = function
      [] -> []
    | (d::ds) as l -> if is_minus d then minus_loop ds else l in
  let rec loop = function
      [] -> []
    | ((PC.TMid0(clt),i) as x)::t1::ts when is_minus t1 ->
	(match minus_loop ts with
	  ((PC.TOEllipsis(_),_)::_) | ((PC.TPOEllipsis(_),_)::_)
	| ((PC.TEllipsis(_),_)::_) as l -> x::(PC.TNothing,i)::(loop l)
	| l -> x::(loop l))
    | t::ts -> t::(loop ts) in
  loop l

let rec drop_double_dots l =
  let start = function
      (PC.TOEllipsis(_),_) | (PC.TPOEllipsis(_),_)
 (* | (PC.TOCircles(_),_) | (PC.TOStars(_),_) *) ->
	true
    | _ -> false in
  let middle = function
      (PC.TEllipsis(_),_) (* | (PC.TCircles(_),_) | (PC.TStars(_),_) *) -> true
    | _ -> false in
  let whenline = function
      (PC.TLineEnd(_),_) -> true
    (*| (PC.TMid0(_),_) -> true*)
    | _ -> false in
  let final = function
      (PC.TCEllipsis(_),_) | (PC.TPCEllipsis(_),_)
 (* | (PC.TCCircles(_),_) | (PC.TCStars(_),_) *) ->
	true
    | _ -> false in
  let any_before x = start x or middle x or final x or whenline x in
  let any_after x = start x or middle x or final x in
  let rec loop ((_,i) as prev) = function
      [] -> []
    | x::rest when any_before prev && any_after x ->
	(PC.TNothing,i)::x::(loop x rest)
    | x::rest -> x :: (loop x rest) in
  match l with
    [] -> []
  | (x::xs) -> x :: loop x xs

let rec fix f l =
  let cur = f l in
  if l = cur then l else fix f cur

(* ( | ... | ) also causes parsing problems *)

exception Not_empty

let rec drop_empty_thing starter middle ender = function
    [] -> []
  | hd::rest when starter hd ->
      let rec loop = function
	  x::rest when middle x -> loop rest
	| x::rest when ender x -> rest
	| _ -> raise Not_empty in
      (match try Some(loop rest) with Not_empty -> None with
	Some x -> drop_empty_thing starter middle ender x
      |	None -> hd :: drop_empty_thing starter middle ender rest)
  | x::rest -> x :: drop_empty_thing starter middle ender rest

let drop_empty_or =
  drop_empty_thing
    (function (PC.TOPar0(_),_) -> true | _ -> false)
    (function (PC.TMid0(_),_) -> true | _ -> false)
    (function (PC.TCPar0(_),_) -> true | _ -> false)

let drop_empty_nest = drop_empty_thing

(* ----------------------------------------------------------------------- *)
(* Read tokens *)

let get_s_starts (_, (s,_,(starts, ends))) =
  Printf.printf "%d %d\n" starts ends; (s, starts)

let pop2 l =
  let v = List.hd !l in
  l := List.tl !l;
  v

let reinit _ =
  PC.reinit (function _ -> PC.TArobArob (* a handy token *))
    (Lexing.from_function
       (function buf -> function n -> raise Common.Impossible))

let parse_one str parsefn file toks =
  let all_tokens = ref toks in
  let cur_tok    = ref (List.hd !all_tokens) in

  let lexer_function _ =
      let (v, info) = pop2 all_tokens in
      cur_tok := (v, info);
      v in

  let lexbuf_fake =
    Lexing.from_function
      (function buf -> function n -> raise Common.Impossible)
  in

  reinit();

  try parsefn lexer_function lexbuf_fake
  with
    Lexer_cocci.Lexical s ->
      failwith
	(Printf.sprintf "%s: lexical error: %s\n =%s\n" str s
	   (Common.error_message file (get_s_starts !cur_tok) ))
  | Parser_cocci_menhir.Error ->
      failwith
	(Printf.sprintf "%s: parse error: \n = %s\n" str
	   (Common.error_message file (get_s_starts !cur_tok) ))
  | Semantic_cocci.Semantic s ->
      failwith
	(Printf.sprintf "%s: semantic error: %s\n =%s\n" str s
	   (Common.error_message file (get_s_starts !cur_tok) ))

  | e -> raise e

let prepare_tokens tokens =
  find_top_init
    (translate_when_true_false (* after insert_line_end *)
       (insert_line_end
	  (detect_types false
	     (find_function_names (detect_attr (check_parentheses tokens))))))

let prepare_mv_tokens tokens =
  detect_types false (detect_attr tokens)

let rec consume_minus_positions = function
    [] -> []
  | ((PC.TOPar0(_),_) as x)::xs | ((PC.TCPar0(_),_) as x)::xs
  | ((PC.TMid0(_),_) as x)::xs -> x::consume_minus_positions xs
  | x::(PC.TPArob,_)::(PC.TMetaPos(name,constraints,per,clt),_)::xs ->
      let (arity,ln,lln,offset,col,strbef,straft,_) = get_clt x in
      let name = Parse_aux.clt2mcode name clt in
      let x =
	update_clt x
	  (arity,ln,lln,offset,col,strbef,straft,
	   Ast0.MetaPos(name,constraints,per)) in
      x::(consume_minus_positions xs)
  | x::xs -> x::consume_minus_positions xs

let any_modif rule =
  let mcode x =
    match Ast0.get_mcode_mcodekind x with
      Ast0.MINUS _ | Ast0.PLUS -> true
    | _ -> false in
  let donothing r k e = k e in
  let bind x y = x or y in
  let option_default = false in
  let fn =
    V0.flat_combiner bind option_default
      mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode
      donothing donothing donothing donothing donothing donothing
      donothing donothing donothing donothing donothing donothing donothing
      donothing donothing in
  List.exists fn.VT0.combiner_rec_top_level rule

let drop_last extra l = List.rev(extra@(List.tl(List.rev l)))

let partition_either l =
  let rec part_either left right = function
  | [] -> (List.rev left, List.rev right)
  | x :: l ->
      (match x with
      | Common.Left  e -> part_either (e :: left) right l
      | Common.Right e -> part_either left (e :: right) l) in
  part_either [] [] l

let get_metavars parse_fn table file lexbuf =
  let rec meta_loop acc (* read one decl at a time *) =
    let (_,tokens) =
      Data.call_in_meta
	(function _ ->
	  tokens_all table file true lexbuf [PC.TArobArob;PC.TMPtVirg]) in
    let tokens = prepare_mv_tokens tokens in
    match tokens with
      [(PC.TArobArob,_)] -> List.rev acc
    | _ ->
	let metavars = parse_one "meta" parse_fn file tokens in
	meta_loop (metavars@acc) in
  partition_either (meta_loop [])

let get_script_metavars parse_fn table file lexbuf =
  let rec meta_loop acc =
    let (_, tokens) =
      tokens_all table file true lexbuf [PC.TArobArob; PC.TMPtVirg] in
    let tokens = prepare_tokens tokens in
    match tokens with
      [(PC.TArobArob, _)] -> List.rev acc
    | _ ->
      let metavar = parse_one "scriptmeta" parse_fn file tokens in
      meta_loop (metavar :: acc)
  in
  meta_loop []

let get_rule_name parse_fn starts_with_name get_tokens file prefix =
  Data.in_rule_name := true;
  let mknm _ = make_name prefix (!Lexer_cocci.line) in
  let name_res =
    if starts_with_name
    then
      let (_,tokens) = get_tokens [PC.TArob] in
      let check_name = function
	  None -> Some (mknm())
	| Some nm ->
	    (if List.mem nm reserved_names
	    then failwith (Printf.sprintf "invalid name %s\n" nm));
	    Some nm in
      match parse_one "rule name" parse_fn file tokens with
	Ast.CocciRulename (nm,a,b,c,d,e) ->
          Ast.CocciRulename (check_name nm,a,b,c,d,e)
      | Ast.GeneratedRulename (nm,a,b,c,d,e) ->
          Ast.GeneratedRulename (check_name nm,a,b,c,d,e)
      | Ast.ScriptRulename(s,deps) -> Ast.ScriptRulename(s,deps)
      | Ast.InitialScriptRulename(s) -> Ast.InitialScriptRulename(s)
      | Ast.FinalScriptRulename(s) -> Ast.FinalScriptRulename(s)
    else
      Ast.CocciRulename(Some(mknm()),Ast.NoDep,[],[],Ast.Undetermined,false) in
  Data.in_rule_name := false;
  name_res

let parse_iso file =
  let table = Common.full_charpos_to_pos file in
  Common.with_open_infile file (fun channel ->
    let lexbuf = Lexing.from_channel channel in
    let get_tokens = tokens_all table file false lexbuf in
    let res =
      match get_tokens [PC.TArobArob;PC.TArob] with
	(true,start) ->
	  let parse_start start =
	    let rev = List.rev start in
	    let (arob,_) = List.hd rev in
	    (arob = PC.TArob,List.rev(List.tl rev)) in
	  let (starts_with_name,start) = parse_start start in
	  let rec loop starts_with_name start =
	    (!Data.init_rule)();
	    (* get metavariable declarations - have to be read before the
	       rest *)
	    let (rule_name,_,_,_,_,_) =
              match get_rule_name PC.iso_rule_name starts_with_name get_tokens
		file ("iso file "^file) with
                Ast.CocciRulename (Some n,a,b,c,d,e) -> (n,a,b,c,d,e)
              | _ -> failwith "Script rules cannot appear in isomorphism rules"
              in
	    Ast0.rule_name := rule_name;
	    let iso_metavars =
	      match get_metavars PC.iso_meta_main table file lexbuf with
		(iso_metavars,[]) -> iso_metavars
	      | _ -> failwith "unexpected inheritance in iso" in
	    (* get the rule *)
	    let (more,tokens) =
	      get_tokens
		[PC.TIsoStatement;PC.TIsoExpression;PC.TIsoArgExpression;
		  PC.TIsoTestExpression;
		  PC.TIsoDeclaration;PC.TIsoType;PC.TIsoTopLevel] in
	    let next_start = List.hd(List.rev tokens) in
	    let dummy_info = ("",(-1,-1),(-1,-1)) in
	    let tokens = drop_last [(PC.EOF,dummy_info)] tokens in
	    let tokens = prepare_tokens (start@tokens) in
            (*
	       print_tokens "iso tokens" tokens;
	    *)
	    let entry = parse_one "iso main" PC.iso_main file tokens in
	    let entry = List.map (List.map Test_exps.process_anything) entry in
	    if more
	    then (* The code below allows a header like Statement list,
		    which is more than one word.  We don't have that any more,
		    but the code is left here in case it is put back. *)
	      match get_tokens [PC.TArobArob;PC.TArob] with
		(true,start) ->
		  let (starts_with_name,start) = parse_start start in
		  (iso_metavars,entry,rule_name) ::
		  (loop starts_with_name (next_start::start))
	      |	_ -> failwith "isomorphism ends early"
	    else [(iso_metavars,entry,rule_name)] in
	  loop starts_with_name start
      | (false,_) -> [] in
    res)

let parse_iso_files existing_isos iso_files extra_path =
  let get_names = List.map (function (_,_,nm) -> nm) in
  let old_names = get_names existing_isos in
  Data.in_iso := true;
  let (res,_) =
    List.fold_left
      (function (prev,names) ->
	function file ->
	  Lexer_cocci.init ();
	  let file =
	    match file with
	      Common.Left(fl)  -> Filename.concat extra_path fl
	    | Common.Right(fl) -> Filename.concat Config.path fl in
	  let current = parse_iso file in
	  let new_names = get_names current in
	  if List.exists (function x -> List.mem x names) new_names
	  then failwith (Printf.sprintf "repeated iso name found in %s" file);
	  (current::prev,new_names @ names))
      ([],old_names) iso_files in
  Data.in_iso := false;
  existing_isos@(List.concat (List.rev res))

let rec parse file =
  let table = Common.full_charpos_to_pos file in
  Common.with_open_infile file (fun channel ->
  let lexbuf = Lexing.from_channel channel in
  let get_tokens = tokens_all table file false lexbuf in
  Data.in_prolog := true;
  let initial_tokens = get_tokens [PC.TArobArob;PC.TArob] in
  Data.in_prolog := false;
  let res =
    match initial_tokens with
    (true,data) ->
      (match List.rev data with
	((PC.TArobArob as x),_)::_ | ((PC.TArob as x),_)::_ ->
	  let include_and_iso_files =
	    parse_one "include and iso file names" PC.include_main file data in

	  let (include_files,iso_files,virt) =
	    List.fold_left
	      (function (include_files,iso_files,virt) ->
		function
		    Data.Include s -> (s::include_files,iso_files,virt)
		  | Data.Iso s -> (include_files,s::iso_files,virt)
		  | Data.Virt l -> (include_files,iso_files,l@virt))
	      ([],[],[]) include_and_iso_files in
	  List.iter (function x -> Hashtbl.add Lexer_cocci.rule_names x ())
	    virt;

	  let (extra_iso_files, extra_rules, extra_virt) =
	    let rec loop = function
		[] -> ([],[],[])
	      |	(a,b,c)::rest ->
		  let (x,y,z) = loop rest in
		  (a::x,b::y,c::z) in
	    loop (List.map parse include_files) in

          let parse_cocci_rule ruletype old_metas
	      (rule_name, dependencies, iso, dropiso, exists, is_expression) =
            Ast0.rule_name := rule_name;
            Data.inheritable_positions :=
		rule_name :: !Data.inheritable_positions;

            (* get metavariable declarations *)
            let (metavars, inherited_metavars) =
	      get_metavars PC.meta_main table file lexbuf in
            Hashtbl.add Data.all_metadecls rule_name metavars;
            Hashtbl.add Lexer_cocci.rule_names rule_name ();
            Hashtbl.add Lexer_cocci.all_metavariables rule_name
              (Hashtbl.fold
		 (fun key v rest -> (key,v)::rest)
		 Lexer_cocci.metavariables []);

            (* get transformation rules *)
            let (more, tokens) = get_tokens [PC.TArobArob; PC.TArob] in
            let (minus_tokens, _) = split_token_stream tokens in
            let (_, plus_tokens) =
	      split_token_stream (minus_to_nothing tokens) in

	    let minus_tokens = consume_minus_positions minus_tokens in
	    let minus_tokens = prepare_tokens minus_tokens in
	    let plus_tokens = prepare_tokens plus_tokens in

	    (*
	       print_tokens "minus tokens" minus_tokens;
	       print_tokens "plus tokens" plus_tokens;
	    *)

	    let plus_tokens =
	      process_pragmas None []
		(fix (function x -> drop_double_dots (drop_empty_or x))
		   (drop_when plus_tokens)) in
	    (*
               print_tokens "plus tokens" plus_tokens;
	       Printf.printf "before minus parse\n";
	    *)
	    let minus_res =
	      if is_expression
	      then parse_one "minus" PC.minus_exp_main file minus_tokens
	      else parse_one "minus" PC.minus_main file minus_tokens in
	    (*
	       Unparse_ast0.unparse minus_res;
	       Printf.printf "before plus parse\n";
	    *)
	    let plus_res =
	      if !Flag.sgrep_mode2
	      then (* not actually used for anything, except context_neg *)
		List.map
		  (Iso_pattern.rebuild_mcode None).VT0.rebuilder_rec_top_level
		  minus_res
	      else
		if is_expression
		then parse_one "plus" PC.plus_exp_main file plus_tokens
		else parse_one "plus" PC.plus_main file plus_tokens in
	    (*
	       Printf.printf "after plus parse\n";
	    *)

	    (if not !Flag.sgrep_mode2 &&
	      (any_modif minus_res or any_modif plus_res)
	    then Data.inheritable_positions := []);

	    Check_meta.check_meta rule_name old_metas inherited_metavars
	      metavars minus_res plus_res;

            (more, Ast0.CocciRule ((minus_res, metavars,
              (iso, dropiso, dependencies, rule_name, exists)),
              (plus_res, metavars), ruletype), metavars, tokens) in

	  let rec collect_script_tokens = function
	      [(PC.EOF,_)] | [(PC.TArobArob,_)] | [(PC.TArob,_)] -> ""
	    | (PC.TScriptData(s),_)::xs -> s^(collect_script_tokens xs)
	    | toks ->
		List.iter
		  (function x ->
		    Printf.printf "%s\n" (token2c x))
		  toks;
		failwith "Malformed script rule" in

          let parse_script_rule language old_metas deps =
            let get_tokens = tokens_script_all table file false lexbuf in

              (* meta-variables *)
            let metavars =
	      Data.call_in_meta
		(function _ ->
		  get_script_metavars PC.script_meta_main table file lexbuf) in

            let exists_in old_metas (py,(r,m)) =
              let test (rr,mr) x =
                let (ro,vo) = Ast.get_meta_name x in
                ro = rr && vo = mr in
              List.exists (test (r,m)) old_metas in

	    List.iter
	      (function x ->
		let meta2c (r,n) = Printf.sprintf "%s.%s" r n in
		if not (exists_in old_metas x) then
		  failwith
		    (Printf.sprintf
		       "Script references unknown meta-variable: %s"
		       (meta2c(snd x))))
	      metavars;

              (* script code *)
            let (more, tokens) = get_tokens [PC.TArobArob; PC.TArob] in
            let data = collect_script_tokens tokens in
            (more,Ast0.ScriptRule(language, deps, metavars, data),[],tokens) in

          let parse_if_script_rule k language =
            let get_tokens = tokens_script_all table file false lexbuf in

              (* script code *)
            let (more, tokens) = get_tokens [PC.TArobArob; PC.TArob] in
            let data = collect_script_tokens tokens in
            (more,k (language, data),[],tokens) in

	  let parse_iscript_rule =
	    parse_if_script_rule
	      (function (language,data) ->
		Ast0.InitialScriptRule(language,data)) in

	  let parse_fscript_rule =
	    parse_if_script_rule
	      (function (language,data) ->
		Ast0.FinalScriptRule(language,data)) in

          let parse_rule old_metas starts_with_name =
            let rulename =
	      get_rule_name PC.rule_name starts_with_name get_tokens file
		"rule" in
            match rulename with
              Ast.CocciRulename (Some s, a, b, c, d, e) ->
                parse_cocci_rule Ast.Normal old_metas (s, a, b, c, d, e)
            | Ast.GeneratedRulename (Some s, a, b, c, d, e) ->
		Data.in_generating := true;
                let res =
		  parse_cocci_rule Ast.Generated old_metas (s,a,b,c,d,e) in
		Data.in_generating := false;
		res
            | Ast.ScriptRulename(l,deps) -> parse_script_rule l old_metas deps
            | Ast.InitialScriptRulename(l) -> parse_iscript_rule l
            | Ast.FinalScriptRulename(l) -> parse_fscript_rule l
            | _ -> failwith "Malformed rule name"
            in

	  let rec loop old_metas starts_with_name =
	    (!Data.init_rule)();

            let gen_starts_with_name more tokens =
              more &&
              (match List.hd (List.rev tokens) with
                    (PC.TArobArob,_) -> false
                  | (PC.TArob,_) -> true
                  | _ -> failwith "unexpected token")
            in

            let (more, rule, metavars, tokens) =
              parse_rule old_metas starts_with_name in
            if more then
              rule::
	      (loop (metavars @ old_metas) (gen_starts_with_name more tokens))
            else [rule] in

	  (List.fold_left
	     (function prev -> function cur -> Common.union_set cur prev)
	     iso_files extra_iso_files,
	   (* included rules first *)
	   List.fold_left (@) (loop [] (x = PC.TArob)) (List.rev extra_rules),
	   List.fold_left (@) virt extra_virt (*no dups allowed*))
      |	_ -> failwith "unexpected code before the first rule\n")
  | (false,[(PC.TArobArob,_)]) | (false,[(PC.TArob,_)]) ->
      ([],([] : Ast0.parsed_rule list),[] (*virtual rules*))
  | _ -> failwith "unexpected code before the first rule\n" in
  res)

(* parse to ast0 and then convert to ast *)
let process file isofile verbose =
  let extra_path = Filename.dirname file in
  Lexer_cocci.init();
  let (iso_files, rules, virt) = parse file in
  let std_isos =
    match isofile with
      None -> []
    | Some iso_file -> parse_iso_files [] [Common.Left iso_file] "" in
  let global_isos = parse_iso_files std_isos iso_files extra_path in
  let rules = Unitary_ast0.do_unitary rules in
  let parsed =
    List.map
      (function
          Ast0.ScriptRule (a,b,c,d) -> [([],Ast.ScriptRule (a,b,c,d))]
	| Ast0.InitialScriptRule (a,b) -> [([],Ast.InitialScriptRule (a,b))]
	| Ast0.FinalScriptRule (a,b) -> [([],Ast.FinalScriptRule (a,b))]
	| Ast0.CocciRule
	    ((minus, metavarsm,
	      (iso, dropiso, dependencies, rule_name, exists)),
	     (plus, metavars),ruletype) ->
	       let chosen_isos =
		 parse_iso_files global_isos
		   (List.map (function x -> Common.Left x) iso)
		   extra_path in
	       let chosen_isos =
            (* check that dropped isos are actually available *)
		 (try
		   let iso_names =
		     List.map (function (_,_,nm) -> nm) chosen_isos in
		   let local_iso_names = reserved_names @ iso_names in
		   let bad_dropped =
		     List.find
		       (function dropped ->
			 not (List.mem dropped local_iso_names))
		       dropiso in
		   failwith
		     ("invalid iso name " ^ bad_dropped ^ " in " ^ rule_name)
		 with Not_found -> ());
		 if List.mem "all" dropiso
		 then
		   if List.length dropiso = 1
		   then []
		   else failwith "disable all should only be by itself"
		 else (* drop those isos *)
		   List.filter
		     (function (_,_,nm) -> not (List.mem nm dropiso))
		     chosen_isos in
	       List.iter Iso_compile.process chosen_isos;
	       let dropped_isos =
		 match reserved_names with
		   "all"::others ->
		     (match dropiso with
		       ["all"] -> others
		     | _ ->
			 List.filter (function x -> List.mem x dropiso) others)
		 | _ ->
		     failwith
		       "bad list of reserved names - all must be at start" in
	       let minus = Test_exps.process minus in
	       let minus = Compute_lines.compute_lines false minus in
	       let plus = Compute_lines.compute_lines false plus in
	       let is_exp =
		 (* only relevant to Flag.make_hrule *)
		 (* doesn't handle multiple minirules properly, but since
		    we don't really handle them in lots of other ways, it
		    doesn't seem very important *)
		 match plus with
		   [] -> [false]
		 | p::_ ->
		     [match Ast0.unwrap p with
		       Ast0.CODE c ->
			 (match List.map Ast0.unwrap (Ast0.undots c) with
			   [Ast0.Exp e] -> true | _ -> false)
		     | _ -> false] in
	       let minus = Arity.minus_arity minus in
	       let ((metavars,minus),function_prototypes) =
		 Function_prototypes.process
		   rule_name metavars dropped_isos minus plus ruletype in
	       let plus = Adjust_pragmas.process plus in
          (* warning! context_neg side-effects its arguments *)
	       let (m,p) = List.split (Context_neg.context_neg minus plus) in
	       Type_infer.type_infer p;
	       (if not !Flag.sgrep_mode2
	       then Insert_plus.insert_plus m p (chosen_isos = []));
	       Type_infer.type_infer minus;
	       let (extra_meta, minus) =
		 match (chosen_isos,ruletype) with
		   (* separate case for [] because applying isos puts
		      some restrictions on the -+ code *)
		   ([],_) | (_,Ast.Generated) -> ([],minus)
		 | _ -> Iso_pattern.apply_isos chosen_isos minus rule_name in
	       (* after iso, because iso can intro ... *)
	       let minus = Adjacency.compute_adjacency minus in
	       let minus = Comm_assoc.comm_assoc minus rule_name dropiso in
	       let minus =
		 if !Flag.sgrep_mode2 then minus
		 else Single_statement.single_statement minus in
	       let minus = Simple_assignments.simple_assignments minus in
	       let minus_ast =
		 Ast0toast.ast0toast rule_name dependencies dropped_isos
		   exists minus is_exp ruletype in
	       
	       match function_prototypes with
		 None -> [(extra_meta @ metavars, minus_ast)]
	       | Some mv_fp -> [(extra_meta @ metavars, minus_ast); mv_fp])
(*          Ast0.CocciRule ((minus, metavarsm, (iso, dropiso, dependencies, rule_name, exists)), (plus, metavars))*)
      rules in
  let parsed = List.concat parsed in
  let disjd = Disjdistr.disj parsed in

  let (metavars,code,fvs,neg_pos,ua,pos) = Free_vars.free_vars disjd in
  if !Flag_parsing_cocci.show_SP
  then List.iter Pretty_print_cocci.unparse code;

  let grep_tokens =
    Common.profile_code "get_constants"
      (fun () -> Get_constants.get_constants code) in (* for grep *)
  let glimpse_tokens2 =
    Common.profile_code "get_glimpse_constants"
      (fun () -> Get_constants2.get_constants code neg_pos) in(* for glimpse *)

  (metavars,code,fvs,neg_pos,ua,pos,grep_tokens,glimpse_tokens2,virt)
