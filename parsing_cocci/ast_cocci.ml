(*
 * This file is part of Coccinelle, lincensed under the terms of the GPL v2.
 * See copyright.txt in the Coccinelle source code for more information.
 * The Coccinelle source code can be obtained at http://coccinelle.lip6.fr
 *)

(* --------------------------------------------------------------------- *)
(* Modified code *)

type added_string = Noindent of string | Indent of string | Space of string

type info = { line : int; column : int;
	      strbef : (added_string * int (* line *) * int (* col *)) list;
	      straft : (added_string * int (* line *) * int (* col *)) list;
              whitespace : string }

type line = int
type meta_name = string * string
(* need to be careful about rewrapping, to avoid duplicating pos info
currently, the pos info is always None until asttoctl2. *)
type 'a wrap =
    {node : 'a;
      node_line : line;
      free_vars : meta_name list; (*free vars*)
      minus_free_vars : meta_name list; (*minus free vars*)
      fresh_vars : (meta_name * seed) list; (*fresh vars*)
      inherited : meta_name list; (*inherited vars*)
      positive_inherited_positions : meta_name list;
      saved_witness : meta_name list; (*witness vars*)
      bef_aft : dots_bef_aft;
      (* the following is for or expressions *)
      pos_info : meta_name mcode option; (* pos info, try not to duplicate *)
      true_if_test_exp : bool;(* true if "test_exp from iso", only for exprs *)
      (* the following is only for declarations *)
      safe_for_multi_decls : bool;
      (* isos relevant to the term; ultimately only used for rule_elems *)
      iso_info : (string*anything) list }

and 'a befaft =
    BEFORE      of 'a list list * count
  | AFTER       of 'a list list * count
  | BEFOREAFTER of 'a list list * 'a list list * count
  | NOTHING

and 'a replacement = REPLACEMENT of 'a list list * count | NOREPLACEMENT

and 'a mcode = 'a * info * mcodekind * meta_pos list (* pos variables *)
    (* pos is an offset indicating where in the C code the mcodekind
       has an effect *)
    (* int list is the match instances, which are only meaningful in annotated
       C code *)
    (* adjacency is the adjacency index, which is incremented on context dots *)
(* iteration is only allowed on context code, the intuition vaguely being
that there is no way to replace something more than once.  Actually,
allowing iterated additions on minus code would cause problems with some
heuristics for adding braces, because one couldn't identify simple
replacements with certainty.  Anyway, iteration doesn't seem to be needed
on - code for the moment.  Although it may be confusing that there can be
iterated addition of code before context code where the context code is
immediately followed by removed code. *)
and adjacency = ALLMINUS | ADJ of int
and mcodekind =
    MINUS       of pos * int list * adjacency * anything replacement
  | CONTEXT     of pos * anything befaft
  | PLUS        of count
and count = ONE (* + *) | MANY (* ++ *)
and fixpos =
    Real of int (* charpos *) | Virt of int * int (* charpos + offset *)
and pos = NoPos | DontCarePos | FixPos of (fixpos * fixpos)

and dots_bef_aft =
    NoDots
  | AddingBetweenDots of statement * int (*index of let var*)
  | DroppingBetweenDots of statement * int (*index of let var*)

and inherited = bool (* true if inherited *)
and keep_binding = Unitary (* need no info *)
  | Nonunitary (* need an env entry *) | Saved (* need a witness *)
and multi = bool (*true if a nest is one or more, false if it is zero or more*)

and end_info =
    meta_name list (*free vars*) * (meta_name * seed) list (*fresh*) *
      meta_name list (*inherited vars*) * mcodekind

(* --------------------------------------------------------------------- *)
(* Metavariables *)

and arity = UNIQUE | OPT | MULTI | NONE

and metavar =
    MetaMetaDecl of arity * meta_name (* name *)
  | MetaIdDecl of arity * meta_name (* name *)
  | MetaFreshIdDecl of meta_name (* name *) * seed (* seed *)
  | MetaTypeDecl of arity * meta_name (* name *)
  | MetaInitDecl of arity * meta_name (* name *)
  | MetaInitListDecl of arity * meta_name (* name *) * list_len (*len*)
  | MetaListlenDecl of meta_name (* name *)
  | MetaParamDecl of arity * meta_name (* name *)
  | MetaParamListDecl of arity * meta_name (*name*) * list_len (*len*)
  | MetaBinaryOperatorDecl of arity * meta_name
  | MetaAssignmentOperatorDecl of arity * meta_name
  | MetaConstDecl of
      arity * meta_name (* name *) * fullType list option
  | MetaErrDecl of arity * meta_name (* name *)
  | MetaExpDecl of
      arity * meta_name (* name *) * fullType list option
  | MetaIdExpDecl of
      arity * meta_name (* name *) * fullType list option
  | MetaLocalIdExpDecl of
      arity * meta_name (* name *) * fullType list option
  | MetaGlobalIdExpDecl of
      arity * meta_name (* name *) * fullType list option
  | MetaExpListDecl of arity * meta_name (*name*) * list_len (*len*)
  | MetaDeclDecl of arity * meta_name (* name *)
  | MetaFieldDecl of arity * meta_name (* name *)
  | MetaFieldListDecl of arity * meta_name (* name *) * list_len (*len*)
  | MetaStmDecl of arity * meta_name (* name *)
  | MetaStmListDecl of arity * meta_name (* name *) * list_len (*len*)
  | MetaFuncDecl of arity * meta_name (* name *)
  | MetaLocalFuncDecl of arity * meta_name (* name *)
  | MetaPosDecl of arity * meta_name (* name *)
  | MetaFmtDecl of arity * meta_name (* name *)
  | MetaFragListDecl of arity * meta_name (* name *) * list_len (*len*)
  | MetaAnalysisDecl of string * meta_name (* name *)
  | MetaDeclarerDecl of arity * meta_name (* name *)
  | MetaIteratorDecl of arity * meta_name (* name *)
  | MetaScriptDecl of metavar option ref * meta_name (* name *)

and list_len = AnyLen | MetaLen of meta_name | CstLen of int

and seed = NoVal | StringSeed of string | ListSeed of seed_elem list
and seed_elem = SeedString of string | SeedId of meta_name

(* --------------------------------------------------------------------- *)
(* --------------------------------------------------------------------- *)
(* Dots *)

and 'a dots = 'a list wrap

(* --------------------------------------------------------------------- *)
(* Identifier *)

and base_ident =
    Id            of string mcode
  | MetaId        of meta_name mcode * idconstraint * keep_binding * inherited
  | MetaFunc      of meta_name mcode * idconstraint * keep_binding * inherited
  | MetaLocalFunc of meta_name mcode * idconstraint * keep_binding * inherited
  | AsIdent       of ident * ident (* as ident, always metavar *)

  | DisjId        of ident list
  | OptIdent      of ident

and ident = base_ident wrap

(* --------------------------------------------------------------------- *)
(* Expression *)

and base_expression =
    Ident          of ident
  | Constant       of constant mcode
  | StringConstant of string mcode (* quote *) * string_fragment dots *
		      string mcode (* quote *)
  | FunCall        of expression * string mcode (* ( *) *
                      expression dots * string mcode (* ) *)
  | Assignment     of expression * assignOp * expression *
	              bool (* true if it can match an initialization *)
  | Sequence       of expression * string mcode (* , *) * expression
  | CondExpr       of expression * string mcode (* ? *) * expression option *
	              string mcode (* : *) * expression
  | Postfix        of expression * fixOp mcode
  | Infix          of expression * fixOp mcode
  | Unary          of expression * unaryOp mcode
  | Binary         of expression * binaryOp * expression
  | Nested         of expression * binaryOp * expression
  | ArrayAccess    of expression * string mcode (* [ *) * expression *
	              string mcode (* ] *)
  | RecordAccess   of expression * string mcode (* . *) * ident
  | RecordPtAccess of expression * string mcode (* -> *) * ident
  | Cast           of string mcode (* ( *) * fullType * string mcode (* ) *) *
                      expression
  | SizeOfExpr     of string mcode (* sizeof *) * expression
  | SizeOfType     of string mcode (* sizeof *) * string mcode (* ( *) *
                      fullType * string mcode (* ) *)
  | TypeExp        of fullType (*type name used as an expression, only in
				  arg or #define*)

  | Paren          of string mcode (* ( *) * expression *
                      string mcode (* ) *)

  | Constructor    of string mcode (* ( *) * fullType * string mcode (* ) *) *
	              initialiser
  | MetaErr        of meta_name mcode * constraints * keep_binding *
	              inherited
  | MetaExpr       of meta_name mcode * constraints * keep_binding *
	              fullType list option * form * inherited
  | MetaExprList   of meta_name mcode * listlen * keep_binding *
                      inherited (* only in arg lists *)
  | AsExpr         of expression * expression (* as expr, always metavar *)
  | AsSExpr        of expression * rule_elem (* as expr, always metavar *)

  | EComma         of string mcode (* only in arg lists *)

  | DisjExpr       of expression list
  | ConjExpr       of expression list
  | NestExpr       of string mcode (* <.../<+... *) *
	              expression dots *
	              string mcode (* ...>/...+> *) *
                      expression option * multi

  (* can appear in arg lists, and also inside Nest, as in:
   if(< ... X ... Y ...>)
   In the following, the expression option is the WHEN  *)
  | Edots          of string mcode (* ... *) * expression option

  | OptExp         of expression

and constraints =
    NoConstraint
  | NotIdCstrt     of general_constraint
  | NotExpCstrt    of expression list
  | SubExpCstrt    of meta_name list

and script_constraint =
      string (* name of generated function *) *
	string (* language *) *
	(meta_name * metavar) list (* params *) *
	string (* code *)

(* Constraints on Meta-* Identifiers, Functions *)
and idconstraint =
    IdNoConstraint
  | IdPosIdSet         of string list * meta_name list
  | IdNegIdSet         of string list * meta_name list
  | IdGeneralConstraint of general_constraint

and general_constraint =
  | IdRegExp           of string * Regexp.regexp
  | IdNotRegExp        of string * Regexp.regexp
  | IdScriptConstraint of script_constraint

and assignOpconstraint =
    AssignOpNoConstraint
  | AssignOpInSet of assignOp list

and binaryOpconstraint =
    BinaryOpNoConstraint
  | BinaryOpInSet of binaryOp list

(* ANY = int E; ID = idexpression int X; CONST = constant int X; *)
and form = ANY | ID | LocalID | GlobalID | CONST (* form for MetaExp *)

and expression = base_expression wrap

and listlen =
    MetaListLen of meta_name mcode * keep_binding * inherited
  | CstListLen of int
  | AnyListLen

and base_string_fragment =
    ConstantFragment of string mcode
  | FormatFragment of string mcode (*%*) * string_format (* format *)
  | Strdots of string mcode
  | MetaFormatList of string mcode (*%*) * meta_name mcode * listlen *
	keep_binding * inherited

and string_fragment = base_string_fragment wrap

and base_string_format =
    ConstantFormat of string mcode
  | MetaFormat of meta_name mcode * idconstraint * keep_binding * inherited

and string_format = base_string_format wrap

and unaryOp = GetRef | GetRefLabel | DeRef | UnPlus |  UnMinus | Tilde | Not
and base_assignOp =
    SimpleAssign of simpleAssignOp mcode
  | OpAssign of arithOp mcode
  | MetaAssign of
      meta_name mcode * assignOpconstraint * keep_binding * inherited
and simpleAssignOp = string
and assignOp = base_assignOp wrap
and fixOp = Dec | Inc

and base_binaryOp =
    Arith of arithOp mcode
  | Logical of logicalOp mcode
  | MetaBinary of
      meta_name mcode * binaryOpconstraint * keep_binding * inherited
and binaryOp = base_binaryOp wrap
and arithOp =
    Plus | Minus | Mul | Div | Mod | DecLeft | DecRight | And | Or | Xor
  | Min | Max
and  logicalOp = Inf | Sup | InfEq | SupEq | Eq | NotEq | AndLog | OrLog

and constant =
    String of string
  | Char   of string
  | Int    of string
  | Float  of string
  | DecimalConst of (string * string * string)

(* --------------------------------------------------------------------- *)
(* Types *)

and base_fullType =
    Type            of bool (* true if all minus *) *
	               const_vol mcode option * typeC
  | AsType          of fullType * fullType (* as type, always metavar *)
  | DisjType        of fullType list (* only after iso *)
  | OptType         of fullType

and base_typeC =
    BaseType        of baseType * string mcode list (* Yoann style *)
  | SignedT         of sign mcode * typeC option
  | Pointer         of fullType * string mcode (* * *)
  | FunctionPointer of fullType *
	          string mcode(* ( *)*string mcode(* * *)*string mcode(* ) *)*
                  string mcode (* ( *)*parameter_list*string mcode(* ) *)
  | Array           of fullType * string mcode (* [ *) *
	               expression option * string mcode (* ] *)
  | Decimal         of string mcode (* decimal *) * string mcode (* ( *) *
	               expression *
	               string mcode option (* , *) * expression option *
	               string mcode (* ) *) (* IBM C only *)
  | EnumName        of string mcode (*enum*) * ident option (* name *)
  | EnumDef  of fullType (* either EnumName or metavar *) *
	string mcode (* { *) * expression dots * string mcode (* } *)
  | StructUnionName of structUnion mcode * ident option (* name *)
  | StructUnionDef  of fullType (* either StructUnionName or metavar *) *
	string mcode (* { *) * annotated_decl dots * string mcode (* } *)
  | TypeName        of string mcode (* pad: should be 'of ident' ? *)

  | MetaType        of meta_name mcode * keep_binding * inherited

and fullType = base_fullType wrap
and typeC = base_typeC wrap

and baseType = VoidType | CharType | ShortType | ShortIntType | IntType
| DoubleType | LongDoubleType | FloatType
| LongType | LongIntType | LongLongType | LongLongIntType
| SizeType | SSizeType | PtrDiffType
| BoolType | Unknown

and structUnion = Struct | Union

and sign = Signed | Unsigned

and const_vol = Const | Volatile

(* --------------------------------------------------------------------- *)
(* Variable declaration *)
(* Even if the Cocci program specifies a list of declarations, they are
   split out into multiple declarations of a single variable each. *)

and base_declaration =
    Init of storage mcode option * fullType * ident * string mcode (*=*) *
	initialiser * string mcode (*;*)
  | UnInit of storage mcode option * fullType * ident * string mcode (* ; *)
  | FunProto of
	fninfo list * ident (* name *) *
	string mcode (* ( *) * parameter_list *
	(string mcode (* , *) * string mcode (* ...... *) ) option *
	string mcode (* ) *) * string mcode (* ; *)
  | TyDecl of fullType * string mcode (* ; *)
  | MacroDecl of storage mcode option *
	ident (* name *) * string mcode (* ( *) *
        expression dots * string mcode (* ) *) * string mcode (* ; *)
  | MacroDeclInit of storage mcode option *
	ident (* name *) * string mcode (* ( *) *
        expression dots * string mcode (* ) *) * string mcode (*=*) *
        initialiser * string mcode (* ; *)
  | Typedef of string mcode (*typedef*) * fullType *
               typeC (* either TypeName or metavar *) * string mcode (*;*)
  | DisjDecl of declaration list
  | MetaDecl of meta_name mcode * keep_binding * inherited
  | MetaField of meta_name mcode * keep_binding * inherited
  | MetaFieldList of meta_name mcode * listlen * keep_binding * inherited
  | AsDecl        of declaration * declaration

  | OptDecl    of declaration

and declaration = base_declaration wrap

and base_annotated_decl =
    DElem of mcodekind (* before the decl *) * bool (* true if all minus *) *
      declaration
  (* Ddots is for a structure declaration *)
  | Ddots    of string mcode (* ... *) * declaration option (* whencode *)

and annotated_decl = base_annotated_decl wrap

(* --------------------------------------------------------------------- *)
(* Initializers *)

and base_initialiser =
    MetaInit of meta_name mcode * keep_binding * inherited
  | MetaInitList of meta_name mcode * listlen * keep_binding * inherited
  | AsInit of initialiser * initialiser (* as init, always metavar *)
  | InitExpr of expression
  | ArInitList of string mcode (*{*) * initialiser dots * string mcode (*}*)
  | StrInitList of bool (* true if all are - *) *
        string mcode (*{*) * initialiser list * string mcode (*}*) *
	initialiser list (* whencode: elements that shouldn't appear in init *)
  | InitGccExt of
      designator list (* name *) * string mcode (*=*) *
	initialiser (* gccext: *)
  | InitGccName of ident (* name *) * string mcode (*:*) *
	initialiser
  | IComma of string mcode (* , *)
  | Idots  of string mcode (* ... *) * initialiser option (* whencode *)

  | OptIni    of initialiser

and designator =
    DesignatorField of string mcode (* . *) * ident
  | DesignatorIndex of string mcode (* [ *) * expression * string mcode (* ] *)
  | DesignatorRange of
      string mcode (* [ *) * expression * string mcode (* ... *) *
      expression * string mcode (* ] *)

and initialiser = base_initialiser wrap

(* --------------------------------------------------------------------- *)
(* Parameter *)

and base_parameterTypeDef =
    VoidParam     of fullType
  | Param         of fullType * ident option

  | MetaParam     of meta_name mcode * keep_binding * inherited
  | MetaParamList of meta_name mcode * listlen * keep_binding * inherited

  | AsParam       of parameterTypeDef * expression (* expr, always metavar *)

  | PComma        of string mcode

  | Pdots         of string mcode (* ... *)

  | OptParam      of parameterTypeDef

and parameterTypeDef = base_parameterTypeDef wrap

and parameter_list = parameterTypeDef dots

(* --------------------------------------------------------------------- *)
(* #define Parameters *)

and base_define_param =
    DParam        of ident
  | DPComma       of string mcode
  | DPdots        of string mcode (* ... *)
  | OptDParam     of define_param

and define_param = base_define_param wrap

and base_define_parameters =
    NoParams     (* not parameter list, not an empty one *)
  | DParams      of string mcode(*( *) * define_param dots * string mcode(* )*)

and define_parameters = base_define_parameters wrap

(* --------------------------------------------------------------------- *)
(* positions *)

(* PER = keep bindings separate, ALL = collect them *)
and meta_collect = PER | ALL

and meta_pos =
    MetaPos of meta_name mcode * pos_constraints list *
      meta_collect * keep_binding * inherited

and pos_constraints =
    PosNegSet of meta_name list
  | PosScript of script_constraint

(* --------------------------------------------------------------------- *)
(* Function declaration *)

and storage = Static | Auto | Register | Extern

(* --------------------------------------------------------------------- *)
(* Top-level code *)

and base_rule_elem =
    FunHeader     of mcodekind (* before the function header *) *
	             bool (* true if all minus, for dropping static, etc *) *
	             fninfo list * ident (* name *) *
	             string mcode (* ( *) * parameter_list *
                     (string mcode (* , *) * string mcode (* ...... *) ) option *
                     string mcode (* ) *)
  | Decl          of annotated_decl

  | SeqStart      of string mcode (* { *)
  | SeqEnd        of string mcode (* } *)

  | ExprStatement of expression option * string mcode (*;*)
  | IfHeader      of string mcode (* if *) * string mcode (* ( *) *
	             expression * string mcode (* ) *)
  | Else          of string mcode (* else *)
  | WhileHeader   of string mcode (* while *) * string mcode (* ( *) *
	             expression * string mcode (* ) *)
  | DoHeader      of string mcode (* do *)
  | WhileTail     of string mcode (* while *) * string mcode (* ( *) *
	             expression * string mcode (* ) *) *
                     string mcode (* ; *)
  | ForHeader     of string mcode (* for *) * string mcode (* ( *) *
                     forinfo *
	             expression option * string mcode (*;*) *
                     expression option * string mcode (* ) *)
  | IteratorHeader of ident (* name *) * string mcode (* ( *) *
	             expression dots * string mcode (* ) *)
  | SwitchHeader  of string mcode (* switch *) * string mcode (* ( *) *
	             expression * string mcode (* ) *)
  | Break         of string mcode (* break *) * string mcode (* ; *)
  | Continue      of string mcode (* continue *) * string mcode (* ; *)
  | Label         of ident * string mcode (* : *)
  | Goto          of string mcode (* goto *) * ident * string mcode (* ; *)
  | Return        of string mcode (* return *) * string mcode (* ; *)
  | ReturnExpr    of string mcode (* return *) * expression *
	             string mcode (* ; *)
  | Exec          of string mcode (* EXEC *) * string mcode (* language *) *
	             exec_code dots * string mcode (* ; *)

  | MetaRuleElem  of meta_name mcode * keep_binding * inherited
  | MetaStmt      of meta_name mcode * keep_binding * metaStmtInfo *
	             inherited
  | MetaStmtList  of meta_name mcode * listlen * keep_binding * inherited

  | Exp           of expression (* matches a subterm *)
  | TopExp        of expression (* for macros body, exp at top level,
				   not subexp *)
  | Ty            of fullType (* only at SP top level, matches a subterm *)
  | TopId         of ident (* only at top level *)
  | TopInit       of initialiser (* only at top level *)
  | Include       of string mcode (*#include*) * inc_file mcode (*file *)
  | Undef         of string mcode (* #define *) * ident (* name *)
  | DefineHeader  of string mcode (* #define *) * ident (* name *) *
	             define_parameters (*params*)
  | Pragma        of string mcode (* #pragma *) * ident * pragmainfo
  | Case          of string mcode (* case *) * expression * string mcode (*:*)
  | Default       of string mcode (* default *) * string mcode (*:*)
  | AsRe          of rule_elem * rule_elem (* always { and MetaStmtList *)
  | DisjRuleElem  of rule_elem list

and base_pragmainfo =
    PragmaTuple of string mcode(* ( *) * expression dots * string mcode(* ) *)
  | PragmaIdList of ident dots
  | PragmaDots of string mcode

and pragmainfo = base_pragmainfo wrap

and forinfo =
    ForExp of expression option * string mcode (*;*)
  | ForDecl of annotated_decl

and fninfo =
    FStorage of storage mcode
  | FType of fullType
  | FInline of string mcode
  | FAttr of string mcode

and metaStmtInfo =
    NotSequencible | SequencibleAfterDots of dots_whencode list | Sequencible

and rule_elem = base_rule_elem wrap

and base_statement =
    Seq           of rule_elem (* { *) *
	             statement dots * rule_elem (* } *)
  | IfThen        of rule_elem (* header *) * statement * end_info (* endif *)
  | IfThenElse    of rule_elem (* header *) * statement *
	             rule_elem (* else *) * statement * end_info (* endif *)
  | While         of rule_elem (* header *) * statement * end_info(*endwhile*)
  | Do            of rule_elem (* do *) * statement * rule_elem (* tail *)
  | For           of rule_elem (* header *) * statement * end_info (*endfor*)
  | Iterator      of rule_elem (* header *) * statement * end_info (*enditer*)
  | Switch        of rule_elem (* header *) * rule_elem (* { *) *
	             statement (*decl*) dots * case_line list * rule_elem(*}*)
  | Atomic        of rule_elem
  | Disj          of statement dots list
  | Conj          of statement dots list
  | Nest          of string mcode (* <.../<+... *) * statement dots *
	             string mcode (* ...>/...+> *) *
	             (statement dots,statement) whencode list * multi *
	             dots_whencode list * dots_whencode list
  | FunDecl       of rule_elem (* header *) * rule_elem (* { *) *
     	             statement dots * rule_elem (* } *) * end_info (*exit*)
  | Define        of rule_elem (* header *) * statement dots
  | AsStmt        of statement * statement (* as statement, always metavar *)
  | Dots          of string mcode (* ... *) *
	             (statement dots,statement) whencode list *
	             dots_whencode list * dots_whencode list
  | OptStm        of statement

and ('a,'b) whencode =
    WhenNot of 'a
  | WhenAlways of 'b
  | WhenModifier of when_modifier
  | WhenNotTrue of rule_elem (* useful for fvs *)
  | WhenNotFalse of rule_elem

and when_modifier =
  (* The following removes the shortest path constraint.  It can be used
     with other when modifiers *)
    WhenAny
  (* The following removes the special consideration of error paths.  It
     can be used with other when modifiers *)
  | WhenStrict
  | WhenForall
  | WhenExists

(* only used with asttoctl *)
and dots_whencode =
    WParen of rule_elem * meta_name (*pren_var*)
  | Other of statement
  | Other_dots of statement dots

and statement = base_statement wrap

and base_case_line =
    CaseLine of rule_elem (* case/default header *) * statement dots
  | OptCase of case_line

and case_line = base_case_line wrap

and base_exec_code =
    ExecEval of string mcode (* : *) * expression
  | ExecToken of string mcode
  | ExecDots of string mcode (* ... *)

and exec_code = base_exec_code wrap

and inc_file =
    Local of inc_elem list
  | NonLocal of inc_elem list
  | AnyInc

and inc_elem =
    IncPath of string
  | IncDots

and base_top_level =
    NONDECL of statement
  | CODE of statement dots
  | FILEINFO of string mcode (* old file *) * string mcode (* new file *)
  | ERRORWORDS of expression list

and top_level = base_top_level wrap

and parser_kind = ExpP | IdP | TyP | AnyP

and rulename =
    CocciRulename of string option * dependency *
	string list (*isos to add*) * string list (*isos to drop*) *
	exists * parser_kind
  | GeneratedRulename of string option * dependency *
	string list * string list * exists * parser_kind
  | ScriptRulename of string option (* name *) * string (* language *) *
	dependency
  | InitialScriptRulename of string option (* name *) * string (* language *) *
	dependency
  | FinalScriptRulename of string option (* name *) * string (* language *) *
	dependency

and ruletype = Normal | Generated

and rule =
    CocciRule of string (* name *) *
	(dependency * string list (* dropped isos *) * exists) * top_level list
	* bool list * ruletype
  | ScriptRule of string (* name *) *
      (* metaname for python (untyped), metavar for ocaml (typed) *)
      string (*language*) * dependency *
	(script_meta_name * meta_name * metavar * mvinit)
	  list (*inherited vars*) *
	meta_name list (*script vars*) * string
  | InitialScriptRule of  string (* name *) *
	string (*language*) * dependency *
	(script_meta_name * meta_name * metavar * mvinit)
	  list (*virtual vars*) *
	string (*code*)
  | FinalScriptRule of  string (* name *) *
	string (*language*) * dependency *
	(script_meta_name * meta_name * metavar * mvinit)
	  list (*virtual vars*) *
	string (*code*)

and script_meta_name = string option (*string*) * string option (*ast*)

and mvinit =
    NoMVInit
  | MVInitString of string
  | MVInitPosList

and dependency =
    Dep of string (* rule applies for the current binding *)
  | AntiDep of string (* rule doesn't apply for the current binding *)
  | EverDep of string (* rule applies for some binding *)
  | NeverDep of string (* rule never applies for any binding *)
  | AndDep of dependency * dependency
  | OrDep of dependency * dependency
  | FileIn of string
  | NotFileIn of string
  | NoDep | FailDep

and rule_with_metavars = metavar list * rule

and anything =
    FullTypeTag         of fullType
  | BaseTypeTag         of baseType
  | StructUnionTag      of structUnion
  | SignTag             of sign
  | IdentTag            of ident
  | ExpressionTag       of expression
  | ConstantTag         of constant
  | UnaryOpTag          of unaryOp
  | AssignOpTag         of assignOp
  | SimpleAssignOpTag   of simpleAssignOp
  | OpAssignOpTag       of arithOp
  | FixOpTag            of fixOp
  | BinaryOpTag         of binaryOp
  | ArithOpTag          of arithOp
  | LogicalOpTag        of logicalOp
  | DeclarationTag      of declaration
  | InitTag             of initialiser
  | StorageTag          of storage
  | IncFileTag          of inc_file
  | Rule_elemTag        of rule_elem
  | StatementTag        of statement
  | ForInfoTag          of forinfo
  | CaseLineTag         of case_line
  | StringFragmentTag   of string_fragment
  | ConstVolTag         of const_vol
  | Token               of string * info option
  | Directive           of added_string list
  | Code                of top_level
  | ExprDotsTag         of expression dots
  | ParamDotsTag        of parameterTypeDef dots
  | StmtDotsTag         of statement dots
  | AnnDeclDotsTag      of annotated_decl dots
  | DefParDotsTag       of define_param dots
  | TypeCTag            of typeC
  | ParamTag            of parameterTypeDef
  | SgrepStartTag       of string
  | SgrepEndTag         of string

(* --------------------------------------------------------------------- *)

and exists = Exists | Forall | Undetermined
(* | ReverseForall - idea: look back on all flow paths; not implemented *)

(* --------------------------------------------------------------------- *)

let mkToken x = Token (x,None)

(* --------------------------------------------------------------------- *)

let lub_count i1 i2 =
  match (i1,i2) with
    (MANY,MANY) -> MANY
  | _ -> ONE

(* --------------------------------------------------------------------- *)

let rewrap model x         = {model with node = x}
let rewrap_mcode (_,a,b,c) x = (x,a,b,c)
let unwrap x               = x.node
let unwrap_mcode (x,_,_,_)  = x
let get_mcodekind (_,_,x,_) = x
let get_line x             = x.node_line
let get_mcode_line (_,l,_,_) = l.line
let get_mcode_col (_,l,_,_)  = l.column
let get_fvs x              = x.free_vars
let set_fvs fvs x          = {x with free_vars = fvs}
let get_mfvs x             = x.minus_free_vars
let set_mfvs mfvs x        = {x with minus_free_vars = mfvs}
let get_fresh x            = x.fresh_vars
let get_inherited x        = x.inherited
let get_inherited_pos x    = x.positive_inherited_positions
let get_saved x            = x.saved_witness
let get_dots_bef_aft x     = x.bef_aft
let set_dots_bef_aft d x   = {x with bef_aft = d}
let get_pos x              = x.pos_info
let set_pos x pos          = {x with pos_info = pos}
let get_test_exp x         = x.true_if_test_exp
let set_test_exp x         = {x with true_if_test_exp = true}
let get_safe_decl x        = x.safe_for_multi_decls
let get_isos x             = x.iso_info
let set_isos x isos        = {x with iso_info = isos}
let get_pos_var (_,_,_,p)  = p
let set_pos_var vr (a,b,c,_) = (a,b,c,vr)
let drop_pos (a,b,c,_)     = (a,b,c,[])

let get_wcfvs (whencode : ('a wrap, 'b wrap) whencode list) =
  Common.union_all
    (List.map
       (function
	   WhenNot(a) -> get_fvs a
	 | WhenAlways(a) -> get_fvs a
	 | WhenModifier(_) -> []
	 | WhenNotTrue(e) -> get_fvs e
	 | WhenNotFalse(e) -> get_fvs e)
       whencode)

(* --------------------------------------------------------------------- *)

let get_meta_name = function
    MetaMetaDecl(_ar,nm) -> nm
  | MetaIdDecl(_ar,nm) -> nm
  | MetaFreshIdDecl(nm,seed) -> nm
  | MetaTypeDecl(_ar,nm) -> nm
  | MetaInitDecl(_ar,nm) -> nm
  | MetaInitListDecl(_ar,nm,nm1) -> nm
  | MetaListlenDecl(nm) -> nm
  | MetaParamDecl(_ar,nm) -> nm
  | MetaParamListDecl(_ar,nm,nm1) -> nm
  | MetaBinaryOperatorDecl(_,name) -> name
  | MetaAssignmentOperatorDecl(_,name) -> name
  | MetaConstDecl(_ar,nm,_ty) -> nm
  | MetaErrDecl(_ar,nm) -> nm
  | MetaExpDecl(_ar,nm,_ty) -> nm
  | MetaIdExpDecl(_ar,nm,_ty) -> nm
  | MetaLocalIdExpDecl(_ar,nm,_ty) -> nm
  | MetaGlobalIdExpDecl(_ar,nm,_ty) -> nm
  | MetaExpListDecl(_ar,nm,_nm1) -> nm
  | MetaDeclDecl(_ar,nm) -> nm
  | MetaFieldDecl(_ar,nm) -> nm
  | MetaFieldListDecl(_ar,nm,_nm1) -> nm
  | MetaStmDecl(_ar,nm) -> nm
  | MetaStmListDecl(_ar,nm,nm1) -> nm
  | MetaFuncDecl(_ar,nm) -> nm
  | MetaLocalFuncDecl(_ar,nm) -> nm
  | MetaPosDecl(_ar,nm) -> nm
  | MetaFmtDecl(_ar,nm) -> nm
  | MetaFragListDecl(_ar,nm,_nm1) -> nm
  | MetaAnalysisDecl(_code,nm) -> nm
  | MetaDeclarerDecl(_ar,nm) -> nm
  | MetaIteratorDecl(_ar,nm) -> nm
  | MetaScriptDecl(_ar,nm) -> nm

(* --------------------------------------------------------------------- *)

and tag2c = function
    FullTypeTag _ -> "FullTypeTag"
  | BaseTypeTag _ -> "BaseTypeTag"
  | StructUnionTag _ -> "StructUnionTag"
  | SignTag _ -> "SignTag"
  | IdentTag _ -> "IdentTag"
  | ExpressionTag _ -> "ExpressionTag"
  | ConstantTag _  -> "ConstantTag"
  | UnaryOpTag _   -> "UnaryOpTag"
  | AssignOpTag _  -> "AssignOpTag"
  | SimpleAssignOpTag _  -> "SimpleAssignOpTag"
  | OpAssignOpTag _  -> "OpAssignOpTag"
  | FixOpTag _     -> "FixOpTag"
  | BinaryOpTag _  -> "BinaryOpTag"
  | ArithOpTag _   -> "ArithOpTag"
  | LogicalOpTag _ -> "LogicalOpTag"
  | DeclarationTag _ -> "DeclarationTag"
  | InitTag _      -> "InitTag"
  | StorageTag _   -> "StorageTag"
  | IncFileTag _   -> "IncFileTag"
  | Rule_elemTag _ -> "Rule_elemTag"
  | StatementTag _ -> "StatementTag"
  | ForInfoTag _   -> "ForInfoTag"
  | CaseLineTag _  -> "CaseLineTag"
  | StringFragmentTag _ -> "StringFragmentTag"
  | ConstVolTag _  -> "ConstVolTag"
  | Token _ -> "Token"
  | Directive _ -> "Directive"
  | Code _ -> "Code"
  | ExprDotsTag _ -> "ExprDotsTag"
  | ParamDotsTag _ -> "ParamDotsTag"
  | StmtDotsTag _ -> "StmtDotsTag"
  | AnnDeclDotsTag _ -> "AnnDeclDotsTag"
  | DefParDotsTag _ -> "DefParDotsTag"
  | TypeCTag _ -> "TypeCTag"
  | ParamTag _ -> "ParamTag"
  | SgrepStartTag _ -> "SgrepStartTag"
  | SgrepEndTag _ -> "SgrepEndTag"

(* --------------------------------------------------------------------- *)

let no_info = { line = 0; column = -1; strbef = []; straft = [];
                whitespace = "" }

let make_term x =
  {node = x;
    node_line = 0;
    free_vars = [];
    minus_free_vars = [];
    fresh_vars = [];
    inherited = [];
    positive_inherited_positions = [];
    saved_witness = [];
    bef_aft = NoDots;
    pos_info = None;
    true_if_test_exp = false;
    safe_for_multi_decls = false;
    iso_info = [] }

let make_inherited_term x inherited inh_pos =
  {node = x;
    node_line = 0;
    free_vars = [];
    minus_free_vars = [];
    fresh_vars = [];
    inherited = inherited;
    positive_inherited_positions = inh_pos;
    saved_witness = [];
    bef_aft = NoDots;
    pos_info = None;
    true_if_test_exp = false;
    safe_for_multi_decls = false;
    iso_info = [] }

let make_meta_rule_elem s d (fvs,fresh,inh) =
  let rule = "" in
  {(make_term
      (MetaRuleElem(((rule,s),no_info,d,[]),Unitary,false)))
  with free_vars = fvs; fresh_vars = fresh; inherited = inh}

let make_meta_decl s d (fvs,fresh,inh) =
  let rule = "" in
  {(make_term
      (MetaDecl(((rule,s),no_info,d,[]),Unitary,false))) with
    free_vars = fvs; fresh_vars = fresh; inherited = inh}

let make_mcode x = (x,no_info,CONTEXT(NoPos,NOTHING),[])

(* --------------------------------------------------------------------- *)

let equal_pos x y = x = y

(* --------------------------------------------------------------------- *)

let string_of_arithOp = function
  | Plus -> "+"
  | Minus -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Mod -> "%"
  | DecLeft -> "<<"
  | DecRight -> ">>"
  | And -> "&"
  | Or -> "|"
  | Xor -> "^"
  | Min -> "<?"
  | Max -> ">?"

let string_of_logicalOp = function
  | Eq -> "=="
  | NotEq -> "!="
  | InfEq -> "<="
  | SupEq -> ">="
  | Sup -> ">"
  | Inf -> "<"
  | AndLog -> "&&"
  | OrLog -> "||"

let string_of_binaryOp op = match (unwrap op) with
  | Arith arithOp -> string_of_arithOp (unwrap_mcode arithOp)
  | Logical logicalOp -> string_of_logicalOp (unwrap_mcode logicalOp)
  | MetaBinary _ -> "MetaBinary"

let string_of_assignOp op = match (unwrap op) with
  | SimpleAssign _ -> "="
  | OpAssign op' ->
    let s = string_of_arithOp (unwrap_mcode op') in
    s ^ "="
  | MetaAssign _ -> "MetaAssign"

let string_of_sign = function
    Signed -> "signed"
  | Unsigned -> "unsigned"

let string_of_baseType = function
    VoidType -> "void"
  | CharType -> "char"
  | ShortType -> "short"
  | ShortIntType -> "short int"
  | IntType -> "int"
  | DoubleType -> "double"
  | LongDoubleType -> "long double"
  | FloatType -> "float"
  | LongType -> "long"
  | LongIntType -> "long int"
  | LongLongType -> "long long"
  | LongLongIntType -> "long long int"
  | SizeType -> "size_t"
  | SSizeType -> "ssize_t"
  | PtrDiffType -> "ptrdiff_t"
  | BoolType -> "bool"
  | Unknown -> "unknown"

let string_of_const_vol = function
    Const -> "const"
  | Volatile -> "volatile"

let string_of_meta_name (_, name) = name

let rec string_of_ident id =
  match unwrap id with
    Id id -> unwrap_mcode id
  | MetaId (m, _, _, _)
  | MetaFunc (m, _, _, _)
  | MetaLocalFunc (m, _, _, _) -> string_of_meta_name (unwrap_mcode m)
  | AsIdent (id, _) -> string_of_ident id
  | OptIdent id -> string_of_ident id ^ "?"
  | DisjId l -> String.concat "|" (List.map string_of_ident l)

let string_of_expression e =
  match unwrap e with
    Ident id -> string_of_ident id
  | _ -> "?"

let string_of_structUnion = function
    Struct -> "struct"
  | Union -> "union"

let rec string_of_typeC ty =
  match unwrap ty with
    BaseType (bt, _) -> string_of_baseType bt ^ " "
  | SignedT (sign, ty') ->
      let ssign = string_of_sign (unwrap_mcode sign) in
      ssign ^ " " ^ Common.default "" string_of_typeC ty'
  | Pointer (ty', _) ->
      string_of_fullType ty' ^ "*"
  | FunctionPointer (ty', _, _, _, _, _, _) ->
      string_of_fullType ty' ^ "(*)()"
  | Array (ty', _, _, _) ->
      string_of_fullType ty' ^ "[]"
  | Decimal(_, _, e0, _, e1, _) ->
      let s0 = string_of_expression e0
      and s1 = Common.default "?" string_of_expression e1 in
      Printf.sprintf "decimal(%s,%s) " s0 s1
  | EnumName (_, name) -> "enum " ^ (Common.default "?" string_of_ident name)
  | StructUnionName (kind, name) ->
      Printf.sprintf "%s %s"
	(string_of_structUnion (unwrap_mcode kind))
	(Common.default "?" string_of_ident name)
  | EnumDef (ty', _, _, _)
  | StructUnionDef (ty', _, _, _) -> string_of_fullType ty'
  | TypeName (name) -> unwrap_mcode name ^ " "
  | MetaType (m, _, _) -> string_of_meta_name (unwrap_mcode m) ^ " "
and string_of_fullType ty =
  match unwrap ty with
    Type (_, None, ty') -> string_of_typeC ty'
  | Type (_, Some const_vol, ty') ->
      string_of_const_vol (unwrap_mcode const_vol) ^ " " ^ string_of_typeC ty'
  | AsType (ty', _) -> string_of_fullType ty'
  | DisjType l -> String.concat "|" (List.map string_of_fullType l)
  | OptType ty -> string_of_fullType ty ^ "?"

let typeC_of_fullType_opt ty =
  match unwrap ty with
    Type (_, None, ty') -> Some ty'
  | _ -> None

let ident_of_expression_opt expression =
  match unwrap expression with
    Ident ident -> Some ident
  | _ -> None

type 'a transformer = {
    baseType: (baseType -> string mcode list -> 'a) option;
    decimal: (string mcode -> string mcode -> expression ->
      string mcode option -> expression option -> string mcode -> 'a) option;
    enumName: (string mcode -> ident option -> 'a) option;
    structUnionName: (structUnion mcode -> ident option -> 'a) option;
    typeName: (string mcode -> 'a) option;
    metaType: (meta_name mcode -> keep_binding -> inherited -> 'a) option
  }

let empty_transformer = {
  baseType = None;
  decimal = None;
  enumName = None;
  structUnionName = None;
  typeName = None;
  metaType = None
}

let rec fullType_map tr ty =
  rewrap ty begin
    match unwrap ty with
      Type (a, b, ty') -> Type (a, b, typeC_map tr ty')
    | AsType (ty0, ty1) ->
        AsType (fullType_map tr ty0, fullType_map tr ty1)
    | DisjType l -> DisjType (List.map (fullType_map tr) l)
    | OptType ty' -> OptType (fullType_map tr ty')
  end
and typeC_map tr ty =
  match unwrap ty with
    BaseType (ty', s) ->
      begin
        match tr.baseType with
          None -> ty
        | Some f -> rewrap ty (f ty' s)
      end
  | Pointer (ty', s) -> rewrap ty (Pointer (fullType_map tr ty', s))
  | FunctionPointer (ty, s0, s1, s2, s3, s4, s5) ->
      rewrap ty (FunctionPointer (fullType_map tr ty, s0, s1, s2, s3, s4, s5))
  | Array (ty', s0, s1, s2) ->
      rewrap ty (Array (fullType_map tr ty', s0, s1, s2))
  | EnumName (s0, ident) ->
      begin
        match tr.enumName with
          None -> ty
        | Some f -> rewrap ty (f s0 ident)
      end
  | StructUnionName (su, ident) ->
      begin
        match tr.structUnionName with
          None -> ty
        | Some f -> rewrap ty (f su ident)
      end
  | TypeName name ->
      begin
        match tr.typeName with
          None -> ty
        | Some f -> rewrap ty (f name)
      end
  | MetaType (name, keep, inherited) ->
      begin
        match tr.metaType with
          None -> ty
        | Some f -> rewrap ty (f name keep inherited)
      end
  | Decimal (s0, s1, e0, s2, e1, s3) ->
      begin
        match tr.decimal with
          None -> ty
        | Some f -> rewrap ty (f s0 s1 e0 s2 e1 s3)
      end
  | SignedT (_, None) -> ty
  | SignedT (sgn, Some ty') ->
      rewrap ty (SignedT (sgn, Some (typeC_map tr ty')))
  | EnumDef (ty', s0, e, s1) ->
      rewrap ty (EnumDef (fullType_map tr ty', s0, e, s1))
  | StructUnionDef (ty', s0, a, s1) ->
      rewrap ty (StructUnionDef (fullType_map tr ty', s0, a, s1))

let rec fullType_fold tr ty v =
  match unwrap ty with
    Type (_, _, ty') -> typeC_fold tr ty' v
  | AsType (ty0, ty1) ->
      let v' = fullType_fold tr ty0 v in
      fullType_fold tr ty1 v'
  | DisjType l -> List.fold_left (fun v' ty' -> fullType_fold tr ty' v') v l
  | OptType ty' -> fullType_fold tr ty' v
and typeC_fold tr ty v =
  match unwrap ty with
    BaseType (ty', s0) -> Common.default v (fun f -> f ty' s0 v) tr.baseType
  | SignedT (_, None) -> v
  | SignedT (_, Some ty') -> typeC_fold tr ty' v
  | Pointer (ty', _)
  | FunctionPointer (ty', _, _, _, _, _, _)
  | Array (ty', _, _, _)
  | EnumDef (ty', _, _, _)
  | StructUnionDef (ty', _, _, _) -> fullType_fold tr ty' v
  | Decimal (s0, s1, e0, s2, e1, s3) ->
      Common.default v (fun f -> f s0 s1 e0 s2 e1 s3 v) tr.decimal
  | EnumName (s0, ident) -> Common.default v (fun f -> f s0 ident v) tr.enumName
  | StructUnionName (su, ident) ->
      Common.default v (fun f -> f su ident v) tr.structUnionName
  | TypeName name -> Common.default v (fun f -> f name v) tr.typeName
  | MetaType (name, keep, inherited) ->
      Common.default v (fun f -> f name keep inherited v) tr.metaType

let fullType_iter tr ty =
  fullType_fold {
    baseType = Common.map_option (fun f ty' s0 () -> f ty' s0) tr.baseType;
    decimal = Common.map_option
      (fun f s0 s1 e0 s2 e1 s3 () -> f s0 s1 e0 s2 e1 s3) tr.decimal;
    enumName = Common.map_option (fun f s0 ident () -> f s0 ident) tr.enumName;
    structUnionName = Common.map_option
      (fun f su ident () -> f su ident) tr.structUnionName;
    typeName = Common.map_option (fun f name () -> f name) tr.typeName;
    metaType = Common.map_option
      (fun f name keep inherited () -> f name keep inherited) tr.metaType
  } ty ()

let rec ident_fold_meta_names f ident v =
  match unwrap ident with
    Id _ -> v
  | MetaId (tyname, _, _, _)
  | MetaFunc (tyname, _, _, _)
  | MetaLocalFunc (tyname, _, _, _) -> f (unwrap_mcode tyname) v
  | AsIdent (ident0, ident1) ->
      let v' = ident_fold_meta_names f ident0 v in
      ident_fold_meta_names f ident1 v'
  | DisjId l ->
      List.fold_left (fun v' ident' -> ident_fold_meta_names f ident' v') v l
  | OptIdent ident' -> ident_fold_meta_names f ident' v

let expression_fold_ident f e v = f (Common.just (ident_of_expression_opt e)) v

let fullType_fold_meta_names f ty v =
  let enumOrStructUnionName _ ident v =
    Common.default v (fun ident' -> ident_fold_meta_names f ident' v) ident in
  fullType_fold { empty_transformer with
    decimal = Some (fun _ _ e1 _ e2 _ v ->
      let v' = expression_fold_ident (ident_fold_meta_names f) e1 v in
      Common.default v'
	(fun e -> expression_fold_ident (ident_fold_meta_names f) e v) e2);
    enumName = Some enumOrStructUnionName;
    structUnionName = Some enumOrStructUnionName;
    metaType = Some (fun tyname _ _ v -> f (unwrap_mcode tyname) v)
  } ty v

let meta_names_of_fullType ty =
  fullType_fold_meta_names
    (fun meta_name meta_names -> meta_name :: meta_names) ty []
