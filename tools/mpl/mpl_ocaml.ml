(*
 * Copyright (c) 2005 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * $Id: mpl_ocaml.ml,v 1.71 2006/02/17 17:28:40 avsm Exp $
 *)

open Printf
open Mpl_utils
open Printer_utils.Printer
open Mpl_cfg

module V = Mpl_typechk.Var
module E = Mpl_typechk.Expr
module T = Mpl_typechk.Types
module S = Mpl_syntaxtree


let print_module e n fn =
    e.p (sprintf "module %s = struct" (String.capitalize n));
    indent_fn e fn;
    e.p "end";
    e.nl ()

let print_record e nm fn =
    e.p (sprintf "type %s = {" nm);
    indent_fn e fn;
    e.p "}";
    e.nl ()

let is_custom_type = function
   |V.Value ("dns_label", _, _)
   |V.Value ("dns_label_comp", _, _)
   |V.Value ("string32",_,_)
   |V.Value ("string8",_,_)
   |V.Value ("mpint",_,_)  
   |V.Value ("boolean",_,_) -> true
   |_ -> false

let is_custom_or_packet_type = function
   |V.Packet _ -> true
   |x -> is_custom_type x

let custom_type_name = function
   |V.Value ("dns_label",_,_) ->
      sprintf "Mpl_dns_label.t"
   |V.Value ("dns_label_comp",_,_) ->
      sprintf "Mpl_dns_label.t"
   |V.Value ("string32",_,_) ->
      sprintf "Mpl_string32.t"
   |V.Value ("string8",_,_) ->
      sprintf "Mpl_string8.t"
   |V.Value ("mpint",_,_) ->
      sprintf "Mpl_mpint.t"
   |V.Value ("boolean",_,_) ->
      sprintf "Mpl_boolean.t"
   |x -> failwith (sprintf "custom_type_name: %s" (V.to_string x))

let custom_type_marshal = function
   |V.Value ("dns_label",_,_) ->
      sprintf "Mpl_dns_label.marshal"
   |V.Value ("dns_label_comp",_,_) ->
      sprintf "Mpl_dns_label.marshal ~comp:true"
   |V.Value ("string32",_,_) ->
      sprintf "Mpl_string32.marshal"
   |V.Value ("string8",_,_) ->
      sprintf "Mpl_string8.marshal"
   |V.Value ("mpint",_,_) ->
      sprintf "Mpl_mpint.marshal"
   |V.Value ("boolean",_,_) ->
      sprintf "Mpl_boolean.marshal"
   |x -> failwith (sprintf "custom_type_marshal: %s" (V.to_string x))

let custom_type_prettyprint id = function
   |V.Value ("dns_label", _, _) 
   |V.Value ("dns_label_comp", _, _) ->
      sprintf "Mpl_dns_label.prettyprint"
   |V.Value ("string32",_,_) ->
      sprintf "Mpl_string32.prettyprint"
   |V.Value ("string8",_,_) ->
      sprintf "Mpl_string8.prettyprint"
   |V.Value ("mpint",_,_) ->
      sprintf "Mpl_mpint.prettyprint"
   |V.Value ("boolean",_,_) ->
      sprintf "Mpl_boolean.prettyprint"
   |x -> failwith (sprintf "custom_type_prettyprint: %s" (V.to_string x))

let custom_type_unmarshal = function
   |V.Value ("dns_label", _, _)
   |V.Value ("dns_label_comp", _, _) ->
      "Mpl_dns_label.unmarshal"
   |V.Value ("string32",_,_) ->
      sprintf "Mpl_string32.unmarshal"
   |V.Value ("string8",_,_) ->
      sprintf "Mpl_string8.unmarshal"
   |V.Value ("mpint",_,_) ->
      sprintf "Mpl_mpint.unmarshal"
   |V.Value ("boolean",_,_) ->
      sprintf "Mpl_boolean.unmarshal"
   |x -> failwith (sprintf "custom_type_unmarshal: %s" (V.to_string x))

let custom_type_size id = function
   |V.Value ("dns_label",_,_)
   |V.Value ("dns_label_comp",_,_) ->
      `Dyn (sprintf "(Mpl_dns_label.size %s)" id)
   |V.Value ("string32",_,_) ->
      `Dyn (sprintf "(Mpl_string32.size %s)" id)
   |V.Value ("string8",_,_) ->
      `Dyn (sprintf "(Mpl_string8.size %s)" id)
   |V.Value ("mpint",_,_) ->
      `Dyn (sprintf "(Mpl_mpint.size %s)" id)
   |V.Value ("boolean",_,_) ->
      `Const 1
   |x -> failwith (sprintf "custom_type_size: %s" (V.to_string x))

let custom_is_const_size v =
   match custom_type_size "" v with
   |`Dyn _ -> false
   |`Const _ -> true

let custom_type_const_of_native v = function
   |V.Value ("dns_label_comp",_,_) ->
      sprintf "(Mpl_dns_label.of_string_list ~comp:true %s)" v;
   |V.Value ("dns_label",_,_) ->
      sprintf "(Mpl_dns_label.of_string_list %s)" v
   |V.Value ("string32",_,_) ->
      sprintf "(Mpl_string32.of_string %s)" v
   |V.Value ("string8",_,_) ->
      sprintf "(Mpl_string8.of_string %s)" v
   |V.Value ("mpint",_,_) ->
      sprintf "(%s)" v
   |V.Value ("boolean",_,_) ->
      sprintf "(Mpl_boolean.of_bool %s)" v
   |x -> failwith (sprintf "custom_type_const_of_native: %s" (V.to_string x))

let custom_type_to_native id = function
   |V.Value ("dns_label",_,_)
   |V.Value ("dns_label_comp",_,_) ->
      sprintf "(Mpl_dns_label.to_string_list %s)" id
   |V.Value ("string32",_,_) ->
      sprintf "(Mpl_string32.to_string %s)" id
   |V.Value ("string8",_,_) ->
      sprintf "(Mpl_string8.to_string %s)" id
   |V.Value ("mpint",_,_) ->
      sprintf "(%s)" id
   |V.Value ("boolean",_,_) ->
      sprintf "(Mpl_boolean.to_bool %s)" id
   |x -> failwith (sprintf "custom_type_to_native: %s" (V.to_string x))

let ocaml_to_native ?(statevar=false) ?(toint=false) env id =
    let vfn = if statevar then find_env_statevar else find_env in
    match (match vfn env id with |None -> failwith "ocaml_ntive" |Some x -> x) with
    |V.S_var (id,sz, (V.Value("bit",V.UInt V.I8,_))) ->
        sprintf "%s" id
    |V.S_var (id,sz, (V.Value("byte",V.UInt V.I8,_))) ->
        sprintf "%s" id
    |V.S_var (id,sz, (V.Value(_,V.UInt V.I8,_))) ->
        interr "ocaml_to_native"
    |V.S_var (id,sz, (V.Value(_,V.UInt V.I16,_))) ->
        sprintf "(%s)" id
    |V.S_var (id,sz, (V.Value(_,V.UInt V.I32,_))) when toint ->
        sprintf "(Int32.to_int %s)" id
    |V.S_var (id,sz, (V.Value(_,V.UInt V.I64,_))) when toint ->
        sprintf "(Int64.to_int %s)" id
    |V.S_var (id,sz, (V.Value(_,V.UInt V.I32,_))) ->
        sprintf "(%s)" id
    |V.S_var (id,sz, (V.Value(_,V.UInt V.I64,_))) ->
        sprintf "(%s)" id
    |V.S_var (id,sz, (V.Array(_,V.UInt V.I8,_))) ->
        sprintf "(Mpl_raw.to_string env %s)" id
    |V.S_var (id,sz, (V.Class _)) ->
        sprintf "%s (* array *)" id
    |V.S_var (id,sz,x) -> custom_type_to_native id x
    |V.S_array (id,sz,_) ->
        sprintf "%s (* array *)" id
    |V.S_class _ ->
        interr "ocaml_int_id: s_class"
    |V.S_unit ->
        interr "ocaml_int_id: s_unit"        

let ocaml_native_print = function
    |V.UInt V.I8
    |V.UInt V.I16 -> "%d"
    |V.UInt V.I32 -> "%ld"
    |V.UInt V.I64 -> "%L"
    |V.String -> "%S"
    |V.Bool -> "%b"
    |V.Opaque -> failwith "ocaml_native_print"

let ocaml_native_ty = function
    |V.UInt V.I8
    |V.UInt V.I16 -> "int"
    |V.UInt V.I32 -> "int32"
    |V.UInt V.I64 -> "int64"
    |V.String -> "string"
    |V.Bool -> "bool"
    |V.Opaque -> failwith "ocaml_native_ty"

let ocaml_string_of_expr ?(statevar=false) ?(rfn=None) ?(toint=false) ty env =
    let rec fn = function
    | S.And (a,b) -> sprintf "(%s && %s)" (fn a) (fn b)
    | S.Or (a,b) -> sprintf "(%s || %s)" (fn a) (fn b)
    | S.Identifier i when statevar -> i
    | S.Identifier i -> ocaml_to_native ~statevar:statevar ~toint:toint env i
    | S.Not e -> sprintf "(not %s)" (fn e)
    | S.True -> "true"
    | S.False -> "false"
    | S.Greater (a,b) -> sprintf "(%s > %s)" (fn a) (fn b)
    | S.Less (a,b) -> sprintf "(%s < %s)"  (fn a) (fn b)
    | S.Greater_or_equal (a,b) -> sprintf "(%s >= %s)"  (fn a) (fn b)
    | S.Less_or_equal (a,b) -> sprintf "(%s <= %s)"  (fn a) (fn b)
    | S.Equals (a,b) -> sprintf "(%s == %s)"  (fn a) (fn b)
    | S.Plus (a,b) -> begin
        match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> sprintf "(%s + %s)" (fn a) (fn b)
        |V.UInt V.I32 -> sprintf "(Int32.add %s %s)" (fn a) (fn b)
        |V.UInt V.I64 -> sprintf "(Int64.add %s %s)" (fn a) (fn b)
        |_ -> failwith "string_of_expr"
    end
    | S.Minus (a,b) -> begin
        match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> sprintf "(%s - %s)" (fn a) (fn b)
        |V.UInt V.I32 -> sprintf "(Int32.sub %s %s)" (fn a) (fn b)
        |V.UInt V.I64 -> sprintf "(Int64.sub %s %s)" (fn a) (fn b)
        |_ -> failwith "string_of_expr"
    end
    | S.Multiply (a,b) -> begin
        match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> sprintf "(%s * %s)" (fn a) (fn b)
        |V.UInt V.I32 -> sprintf "(Int32.mul %s %s)" (fn a) (fn b)
        |V.UInt V.I64 -> sprintf "(Int64.mul %s %s)" (fn a) (fn b)
        |_ -> failwith "string_of_expr"
    end
    | S.Divide (a,b) -> begin
        match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> sprintf "(%s / %s)" (fn a) (fn b)
        |V.UInt V.I32 -> sprintf "(Int32.div %s %s)" (fn a) (fn b)
        |V.UInt V.I64 -> sprintf "(Int64.div %s %s)" (fn a) (fn b)
        |_ -> failwith "string_of_expr"
    end
    | S.Int_constant a -> begin
        let s = match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> ""
        |V.UInt V.I32 -> "l"
        |V.UInt V.I64 -> "L"
        |x -> interr "int_constant" in
        sprintf "%Lu%s" a s
    end
    | S.String_constant a -> sprintf "\"%s\"" a
    | S.Range (a,b) -> begin
        match rfn with
        |None -> interr "range not allowed in ocaml expr"
        |Some fn ->
            fn (E.to_const_int a) (E.to_const_int b)
    end
    | S.Function_call ("offset",Some f) ->
        let x = sprintf "%s___offset" f in
        let s = match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> x
        |V.UInt V.I32 -> sprintf "(Int32.of_int %s)" x
        |V.UInt V.I64 -> sprintf "(Int64.of_int %s)" x
        |_ -> failwith "ocaml_string_of_expr: offset"
        in s
    | S.Function_call ("sizeof",Some f) ->
        let x = sprintf "%s___sizeof" f in
        let s = match ty with
        |V.UInt V.I8
        |V.UInt V.I16 -> x
        |V.UInt V.I32 -> sprintf "(Int32.of_int %s)" x
        |V.UInt V.I64 -> sprintf "(Int64.of_int %s)" x
        |_ -> failwith "ocaml_string_of_expr: sizeof"
        in s
    | S.Function_call ("remaining",None) -> "(length env - __pos)"
    | S.Function_call ("array_length",Some f) -> sprintf "(Array.length %s)" f
    | S.Function_call (x,y) -> interr (sprintf "func '%s' not implemented yet" x)
    in fn

let ocaml_const_of_native env sz =
    let rex t = ocaml_string_of_expr t env sz in
    function
    |V.Value (_,(V.UInt V.I8 as b),_) ->
        sprintf "(%s)" (rex b)
    |V.Value (_,(V.UInt V.I16 as b),_) ->
        sprintf "(%s)" (rex b)
    |V.Value (_,(V.UInt V.I32 as b),_) ->
        sprintf "(%s)" (rex b)
    |V.Value (_,(V.UInt V.I64 as b),_)->
        sprintf "(%s)" (rex b)
    |V.Value (_,b,_) as x ->
      custom_type_const_of_native (rex b) x
    |_ -> failwith "ocaml_const_of_native"

let ocaml_const_of_id id =
    function
    |V.Value (_,_,{V.av_variant=Some _}) ->
        id
    |V.Value ("bit",(V.UInt V.I8),_) ->
        failwith "bit match failure in mplc" (* sprintf "(Mpl_bit.of_int %s)" id *)
    |V.Value ("byte",(V.UInt V.I8),_) ->
        sprintf "(%s)" id
    |V.Value (_,(V.UInt V.I16),_) ->
        sprintf "(%s)" id
    |V.Value (_,(V.UInt V.I32),_) ->
        sprintf "(%s)" id
    |V.Value (_,(V.UInt V.I64),_) ->
        sprintf "(%s)" id
    |V.Array (_,(V.UInt V.I8),_) ->
        sprintf "%s" id
    |V.Class x ->
        id
    |x ->
        custom_type_const_of_native id x
    
 let ocaml_size_of_ty env id szo l =
    let r = match l with
    |V.Value ("bit",V.UInt V.I8,_) -> `Const 0
    |V.Value ("byte",V.UInt V.I8,_) ->
        `Const 1
    |V.Value (_,V.UInt V.I16,_) ->
        `Const 2
    |V.Value (_,V.UInt V.I32,_) ->
        `Const 4
    |V.Value (_,V.UInt V.I64,_)->
        `Const 8
    |V.Label ->
        `Const 0
    |V.Packet (p,_) -> 
        (* XXX could read a static size from an external
           interface file but not yet *)
        `Dyn (sprintf "(%s.sizeof %s)" p id)
    |V.Array (_,V.UInt V.I8,_) -> begin
        let sz = must (fun x -> x) szo in
        try `Const (E.to_const_int sz)
        with _ -> `DynLength id
    end
    |V.Class id -> `DynClass id
    |x -> custom_type_size id x
    in (id,r)

let dbg x = prerr_endline (sprintf "[dbg] %s" x)
let fold_sizes ~dynlenfn ~dynclassfn xl =
    let xs = List.fold_left (fun a (id,b) -> match b with
        |`Const c ->
            (string_of_int c) :: a
        |`DynLength id ->
            (dynlenfn id) :: a
        |`DynClass cid ->
            (dynclassfn cid id) :: a
        |`Dyn x ->
            x :: a
    ) [] xl in
    let r = String.concat "+" (List.filter ((<>) "0") xs) in
    if String.length r = 0 then "0" else r

let foldfn1 ?(sub=[]) ?(vpref="") x =
   fold_sizes ~dynlenfn:(fun id -> sprintf "%s%s_length" vpref id)
      ~dynclassfn:(fun cid id ->
         sprintf "(Array.fold_left (fun a x -> %ssizeof x + a) 0 %s%s)" (modname ~sub:sub cid) vpref id) x

let print_variant_types env e l =
    List.iter (fun (id,v) ->
        e += "type %s_t = [" $ id;
        e --> (fun e ->
          List.iter (fun (ex,l) ->
            e += "|`%s" $ l
          ) v.vt_b;
          e += "|`Unknown of %s" $ (ocaml_native_ty v.vt_ty);
        );
        e += "]";
        e.nl ();
        e += "let %s_marshal (a:%s_t) =" $ id $ id;
        e --> (fun e ->
          e += "match a with";
          List.iter (fun (ex,l) ->
             e += "|`%s -> %s" $ l $ (ocaml_string_of_expr v.vt_ty env ex)
          ) v.vt_b;
          e += "|`Unknown x -> x"
        );
        e.nl ();
        e += "let %s_unmarshal a : %s_t =" $ id $ id;
        e --> (fun e ->
          e += "match a with";
          List.iter (fun (ex,l) ->
            e += "|%s -> `%s" $ (ocaml_string_of_expr v.vt_ty env ex) $ l 
          ) v.vt_b;
          e += "|x -> `Unknown x"
        );
        e.nl ();
        e += "let %s_to_string (a:%s_t) =" $ id $ id;
        e --> (fun e ->
          e += "match a with";
          List.iter (fun (ex,l) ->
            e += "|`%s -> \"%s\"" $ l $ l
          ) v.vt_b;
            e += "|`Unknown x -> Printf.sprintf \"%s\" x" $ (ocaml_native_print v.vt_ty)
        );
        e.nl ();
        e += "let %s_of_string s : %s_t option = match s with" $ id $ id;
        e --> (fun e ->
          List.iter (fun (ex,l) ->
            e += "|\"%s\" -> Some `%s" $ l $ l
          ) v.vt_b;
          e += "|_ -> None"
        );
        e.nl ();
    ) (get_variant_types env l)

let print_unmarshal env e l =
    e += "let unmarshal ";
    e --> (fun e ->
      List.iter (fun (id,_) ->
        e += "~(%s:bool)" $ id
      ) env.statevars;
    );
    e --> (fun e ->
      e += "(env:t) : o =";
      e += "let __pos = 0 in";
      let rec fn envstr dum env e = function
      |V.S_var (id,szo,ty) :: r -> begin
        let env = var_bind_env env id szo ty in
        let prfn x sz = e += "let %s = %s in let __pos = __pos + %s in" $ id $ x $ sz in
        let dum = match ty with
        |V.Value (_,_,{V.av_bitdummy=true}) -> dum @ [id]
        |_ -> dum in
        let vvars = get_value_vars env r in
        let _ =  match ty with
        |V.Array (_,(V.UInt V.I8 as b),_) ->
          let sz = must (fun x -> x) szo in
          if not (E.is_const sz) then (
            e += "let %s_length = %s in" $ id $ (ocaml_string_of_expr ~toint:true b env sz);
          )
        |_ -> () in
        if List.mem id vvars then begin
          match ty with
          |V.Value ("bit",V.UInt V.I8,at) ->
            e += "let %s = %s in (* bitu *)" $ id $ (B.to_expr dum at.V.av_bitops);
          |V.Value ("byte",V.UInt V.I8,at) ->
            prfn "to_byte env __pos" "1";
          |V.Value (_,V.UInt V.I8,_) -> interr "print_unmarshal"
          |V.Value (_,V.UInt V.I16,_) -> prfn "to_uint16_be env __pos" "2";
          |V.Value (_,V.UInt V.I32,_) -> prfn "to_uint32_be env __pos" "4";
          |V.Value (_,V.UInt V.I64,_) -> prfn "to_uint64_be env __pos" "8";
          |V.Array (xt,(V.UInt V.I8 as b),_) ->
            let sz = must (fun x -> x) szo in
            let osz = ocaml_string_of_expr ~toint:true b env sz in
            prfn (sprintf "to_string env __pos (%s)" osz) osz;
          |V.Label -> ()
          |ty ->
            prfn (custom_type_unmarshal ty ^ " env __pos") (foldfn1 [ocaml_size_of_ty env id szo ty])
        end else begin
          match ty with
          |V.Value ("bit",V.UInt V.I8,at) -> ()
          |V.Packet (p,args) ->
            if List.length args > 0 then
              failwith "propagating args across packets not yet supported, sorry!";
            (* need to rebase the environment since this packet is foreign *)
            e += "let ___%s___env = sub env __pos 0 in" $ id;
            e += "let %s = %s.unmarshal ___%s___env in" $ id $ p $ id;
            (* skip forward by the amount of  unmarshalling that happened *)
            e += "let __pos = __pos + (length ___%s___env) in" $ id;
          |ty -> 
            let sst = foldfn1 [ocaml_size_of_ty env id szo ty] in
            if is_custom_type ty then begin
              e += "let %s = %s env __pos in (* custom *)" $ id $ (custom_type_unmarshal ty);
              e += "let __pos = %s + __pos in" $ sst;
            end else begin
              e += "let __pos = %s + __pos in (* skipped %s *)" $ sst $ id ;
            end;
        end;
        if Hashtbl.mem env.offsets id then
          e += "let %s___offset = __pos in" $ id;
        fn envstr dum env e r;
      end
      |V.S_class (id, idty, l) :: r ->
        e += "match %s with" $ (ocaml_to_native env id);
        List.iter (fun (ex,bid,gu,xs) ->
          let env = class_bind_env env id bid ex in
          let rstr = ref [] in
          let rfn a b = 
            let ui = "__gu" ^ id in
            rstr := sprintf "((%s >= %d) && (%s <= %d))" ui a ui b :: !rstr;
            ui
          in
          let mtch = ocaml_string_of_expr ~rfn:(Some rfn) idty env ex in
          may (fun gu ->
            rstr := sprintf "(%s)" (ocaml_string_of_expr ~statevar:true V.Bool env gu) :: !rstr) gu;
          let rstr = if List.length !rstr > 0 then sprintf " when %s" (String.concat " && " !rstr) else "" in
          e += "|%s%s -> `%s (" $ mtch $ rstr $ (E.to_const_string bid);
          e --> (fun e -> fn envstr dum env e (xs @ r));
          e += ")";
        ) l;
        e += "|x -> raise (Bad_packet (Printf.sprintf \"%s: %s\" x))" $ (modname env.mods) $ (ocaml_native_print idty)
      |V.S_array (id,sz,xs) :: r ->
        let aenv = array_bind_env env id sz in
        let nenv = {aenv with vars=[]; inarr=true; mods=id::env.mods} in
        e += "let __lpos = ref __pos in";
        e += "let %s =" $ id;
        e --> (fun e ->
          e += "Array.init %s (fun _ ->" $ (ocaml_string_of_expr (V.UInt V.I16) env sz);
          e --> (fun e ->
            e += "let __start_pos = !__lpos in";
            e += "let __pos = __start_pos in";
            e += "let __res =";
            e --> (fun e ->
              fn (sprintf "(sub env __start_pos (__pos - __start_pos))") dum nenv e xs;
            );
            e += "in __lpos := __pos; __res"
          );
          e += ") in";
        );
        e += "let __pos = !__lpos in";
        fn envstr dum aenv e r
      |V.S_unit :: r->
        fn envstr dum env e r
      |[] ->
        e += "seek env __pos;";
        let obj = modname env.mods in
        e += "{ %senv = %s;" $ obj $ envstr;
        e --> (fun e ->
          List.iter (function
            |`Free (id,szo,V.Array (_,V.UInt V.I8,_))
            |`Bound (id,szo,V.Array (_,V.UInt V.I8,_)) ->
               if not (must E.is_const szo) then 
                  e +=  "%s%s_length=%s_length;" $ obj $ id $ id
            |`Free (id,szo,V.Packet _)
            |`Free (id,szo,V.Class _) ->
               e+= "%s%s=%s;" $ obj $ id $ id;
            |`Bound (id,szo,vty) ->
               if is_custom_type vty && not (custom_is_const_size vty) then 
                 e += "%s%s=%s;" $ obj $ id $ id
            |`Free (id,szo,vty) ->
               if is_custom_type vty then 
                 e += "%s%s=%s;" $ obj $ id $ id
            |_ -> ()
          ) (get_free_vars env)
        );
       e += "}";
    in fn "env" [] env e l
    )

let print_struct env e l = 
    let rec fn env e m = function
    |V.S_var (id,szo,ty) :: r ->
        let env = var_bind_env env id szo ty in
        fn env e m r
    |V.S_array (id, sz, xs) :: r ->
        let aenv = array_bind_env env id sz in
        let nenv = {aenv with vars=[]; mods=id::env.mods} in
        print_module e id (fun e ->
            print_variant_types env e xs;
            fn nenv e m xs;
        );
        fn aenv e m r
    |V.S_class (id,idty,l) :: r ->
        let ts = ref [] in
        let ps = ref [] in
        let ss = ref [] in
        let es = ref [] in
        let varl = ref [] in
        let varm = ref [] in
        List.iter (fun (ex,b,_,xs) ->
            let env = class_bind_env env id b ex in
            let f = List.filter (function |V.S_class _ -> true |_ -> false) (xs @ r) in
            let bs = E.to_const_string b in
            let m = bs::m in
            let capb = String.capitalize bs in
            print_module e (E.to_const_string b) (fun e ->
                 print_variant_types env e (xs @ r);
                fn env e m (xs @ r)
            );
            varl := sprintf "|`%s of (t -> %s.o)" capb capb :: !varl;
            varm := sprintf "|`%s (fn:(t->%s.o)) -> `%s (fn env)" capb capb capb :: !varm;
            let vs = if List.length f > 0 then begin
                sprintf "|`%s of %s.o" capb capb
            end else begin
                sprintf "|`%s of %s.o" capb capb
            end in
            let vps = sprintf "|`%s x -> %s.prettyprint x" capb capb in
            let szs = sprintf "|`%s x -> %s.sizeof x" capb capb in
            let ess = sprintf "|`%s x -> %s.env x" capb capb in
            ps := vps :: !ps;
            ts := vs :: !ts;
            ss := szs :: !ss;
            es := ess :: !es;
        ) l;
        let print_var_list x = List.iter (fun a -> e += "%s" $ a) !x in
        e += "type o = [";
        print_var_list ts;
        e +=  "]";
        e.nl ();
        e += "type x = [";
        print_var_list varl;
        e += "]";
        e.nl();
        e += "let m (x:x) env : o = match x with";
        print_var_list varm;
        e.nl ();
        e += "let prettyprint (x:o) = match x with";
        print_var_list ps;
        e.nl ();
        e += "let sizeof (x:o) = match x with";
        print_var_list ss;
        e.nl ();
        e += "let env (x:o) = match x with";
        print_var_list es;
        e.nl ();
    |V.S_unit :: r -> 
        fn env e m r
    |[] ->
        let fvars = get_free_vars env in
        e += "type o = {";
        e --> (fun e ->
          e += "env: t;";
          List.iter (function
            |`Free (id,szo,V.Array (_,V.UInt V.I8,_))
            |`Bound (id,szo,V.Array (_,V.UInt V.I8,_)) ->
              if not (must E.is_const szo) then 
                e += "%s_length: int;" $ id
            |`Free (id,szo,V.Packet (p,_)) ->
              e += "%s: %s.o;" $ id $ p;
            |`Free (id,szo,V.Class cid) ->
              e += "%s: %so array;" $ id $ (modname ~sub:env.mods cid);
              e += "(* mods:[%s], instr:false *)" $ (String.concat "," (List.rev env.mods));
            |`Bound (id,szo,vty) ->
              if is_custom_type vty && not (custom_is_const_size vty) then
                e += "%s: %s;" $ id $ (custom_type_name vty);
            |`Free (id,szo,vty) ->
              if is_custom_type vty then 
                e += "%s: %s;" $ id $ (custom_type_name vty);
            |_ -> ()
          ) fvars;
       );
       e += "}";
       let all_szs = List.fold_right (fun b a -> match b with
         |`Free (id,szo,V.Label)
         |`Bound (id,szo,V.Label)
         |`Free (id,szo,V.Value ("bit",_,_))
         |`Bound (id,szo,V.Value ("bit",_,_)) ->
           a
         |`Free (id,szo,vty)
         |`Bound (id,szo,vty) ->
           ocaml_size_of_ty env id szo vty :: a
       ) fvars [] in
       e += "let env o = copy o.env";
       e += "let sizeof (o:o) =";
       e --> (fun e ->
         List.iter (function
           |`Free (id,szo,ty) ->
             if is_custom_or_packet_type ty then
               e.p (sprintf "let %s = o.%s in (* custom *)" id id)
           |_ -> ()
         ) fvars;
         e += "%s" $ (foldfn1 ~sub:env.mods ~vpref:"o." all_szs);
       );
       let szs = ref [] in
       let szshash = Hashtbl.create 1 in
       let extramthds = ref [] in
       List.iter (fun vl ->
         let _ = match vl with
         |`Bound (id,szo,V.Label) ->
           e += "let %s (o:o) =" $ id;
           e --> (fun e ->
             List.iter (function
              |`Free (id,szo,ty) ->
               if is_custom_or_packet_type ty then
                 e.p (sprintf "let %s = o.%s in (* custom *)" id id)
              |_ -> ()
             ) fvars;
             e += "%s" $ (foldfn1 ~sub:env.mods ~vpref:"o." !szs)
           )
         |`Bound (_,_,V.Value (_,_,{V.av_bitdummy=true})) -> ()
         |`Bound (id,szo,v) -> ()
         |`Free (id,szo,v) -> begin
           e += "let %s (o:o) =" $ id;
           e --> (fun e ->
             List.iter (function
              |`Free (id,szo,ty) ->
               if is_custom_or_packet_type ty then
                 e.p (sprintf "let %s = o.%s in (* custom *)" id id)
              |_ -> ()
             ) fvars;
             let foldfn = foldfn1 ~sub:env.mods ~vpref:"o." in
             let sizeat id = foldfn (Hashtbl.find szshash id) in
             let off = sprintf "(%s)" (foldfn !szs) in
             let prfn x = match v with
              |V.Value (_,_,{V.av_variant=Some _}) -> e += "let %s = %s in" $ id $ x
              |_ -> e += "%s" $ x in
             let _ = match v with
              |V.Value ("bit",V.UInt V.I8,at) ->
                let bvars = find_bit_vars env id in
                let depvars = List.map (fun (a,_) -> a) (B.bitdeps bvars at.V.av_bitops) in
                List.iter (fun id ->
                  e += "let %s = to_byte o.env (%s) in" $ id $ (sizeat id);
                ) depvars;
                prfn (B.to_expr depvars at.V.av_bitops);
              |V.Value ("byte",V.UInt V.I8,_) ->
                prfn (sprintf "to_byte o.env (%s)" off);
              |V.Value (_,V.UInt V.I16,_) ->
                prfn(sprintf "to_uint16_be o.env (%s)" off);
              |V.Value (_,V.UInt V.I32,_) ->
                prfn (sprintf "to_uint32_be o.env (%s)" off);
              |V.Value (_,V.UInt V.I64,_) ->
                prfn (sprintf "to_uint64_be o.env (%s)" off);
              |V.Array (_,V.UInt V.I8,_) ->
                let ssz =
                  if must E.is_const szo then
                    sprintf "%d" (must E.to_const_int szo)
                  else 
                    sprintf "o.%s_length" id 
                in
                prfn (sprintf "to_string o.env %s %s" off ssz);
                let envmt = (sprintf "%s_sub_view" id),(sprintf "sub o.env %s %s" off ssz) in
                let envmt2 = (sprintf "%s_length" id),ssz in
                extramthds := envmt :: envmt2 :: !extramthds;
              |V.Class _ ->
                prfn ("o."^ id)
              |V.Packet _ ->
                e += "%s" $ id
              |x ->
                e += "%s" $ (custom_type_to_native id x)
              in
              let _ = match v with
              |V.Value (_,_,{V.av_variant=Some l}) ->
                e += "%s_unmarshal %s" $ id $ id;
              |_ -> () in
              ()
            );
            let foldfn = foldfn1 ~sub:env.mods ~vpref:"o." in
            let off = sprintf "(%s)" (foldfn !szs) in
            let prfn x =
              e += "let set_%s (o:o) v =" $ id;
              e --> (fun e ->
              List.iter (function
                |`Free (id,szo,ty) ->
                 if is_custom_or_packet_type ty then
                   e.p (sprintf "let %s = o.%s in (* custom *)" id id)
               |_ -> ()
               ) fvars;
               e += "%s" $ x) in
              let unsup x = e += "(* set_%s unsupported for now (type %s) *)" $ id $ x in                         
              match v with
              |V.Value ("bit",V.UInt V.I8,at) ->
                  unsup "bit";
              |V.Value ("byte",V.UInt V.I8,_) ->
                  prfn (sprintf "set_byte o.env %s v" off);
              |V.Value (_,V.UInt V.I16,_) ->
                  prfn (sprintf "set_uint16_be o.env %s v" off);
              |V.Value (_,V.UInt V.I32,_) ->
                  prfn (sprintf "set_uint32_be o.env %s v" off);
              |V.Value (_,V.UInt V.I64,_) ->
                  prfn (sprintf "set_uint64_be o.env %s v" off);
              |V.Array (_,V.UInt V.I8,_) ->
                  unsup "byte array"; 
              |V.Class _ ->
                  unsup "class";
              |x ->
                  unsup "custom_type";
              end in
            List.iter (fun (nm,bd) ->
              e += "let %s (o:o) =" $ nm;
              e --> (fun e ->
                List.iter (function
                |`Free (id,szo,ty) ->
                 if is_custom_or_packet_type ty then
                   e.p (sprintf "let %s = o.%s in (* custom *)" id id)
                |_ -> ()
                ) fvars;
                e += "%s" $ bd
              )
            ) !extramthds;
            extramthds := [];
            e.nl ();
            let _ = match vl with
            |`Free (id,szo,V.Value ("bit",(V.UInt V.I8),_))
            |`Bound (id,szo,V.Value ("bit",(V.UInt V.I8),_)) -> ()
            |`Bound (id,szo,v)
            |`Free (id,szo,v) ->
              let x = ocaml_size_of_ty env id szo v in
              Hashtbl.add szshash id (!szs);
              szs := x :: !szs;
            in ()
          ) fvars;
          e.nl ();
          e.p "let prettyprint o =";
          e --> (fun e ->
          e += "let out = prerr_endline in";
          e += "out \"[ %s.%s ]\";" $ (String.capitalize env.pname) $ (String.concat "." (List.rev (env.pname::env.mods)));
          List.iter (function
            |`Bound (id,szo,v) ->
              e += "(* %s : bound *)" $ id;
            |`Free (id,szo,v) ->
              let vr = "(" ^ id ^ " o)" in
              let prfn x = e += "out (\"  %s = \" ^ (%s %s)); (* XX *)" $ id $ x $ vr in
              let _ = match v with
              |V.Value (_,_,{V.av_variant=Some _}) -> prfn (sprintf "%s_to_string" id)
                |V.Value (_,V.UInt V.I8,_)
                |V.Value (_,V.UInt V.I16,_) -> prfn "Printf.sprintf \"%u\""
                |V.Value (_,V.UInt V.I32,_) -> prfn "Printf.sprintf \"%lu\""
                |V.Value (_,V.UInt V.I64,_) -> prfn "Printf.sprintf \"%Lu\""
                |V.Array (_,V.UInt V.I8,_) -> prfn "Prettyprint.hexdump"
                |V.Class cid -> 
                  e += "out (\"  %s = array\");" $ id;
                  e += "Array.iter %sprettyprint o.%s;" $ (modname ~sub:env.mods cid) $ id;
                |V.Packet (p,_) -> 
                  e += "out (\" %s = packet(%s)\");" $ id $ p;
                  e += "%s.prettyprint o.%s;" $ p $ id;
                |x -> prfn (custom_type_prettyprint id x);
                in ()
              ) fvars;
              e += "()";
            );
        e.nl ();
        e.p ("let t");
        (* output all the optional args first *)
        let def_fvars,other_fvars = List.partition (function
         |  `Free (_,_,V.Value (_,_,{V.av_default=Some _})) -> true
         | _ -> false) fvars in
   
        list_iter_indent e (fun e -> function
            |`Free (id,szo,V.Array (_,V.UInt V.I8,_)) ->
               e.p (sprintf "~(%s:('a data))" id);
            |`Free (id,szo,V.Value (_,_,{V.av_variant=Some vr;V.av_default=Some dexp})) ->
               let vname = List.assoc dexp vr in
               e.p (sprintf "?(%s=`%s)" id vname)
            |`Free (id,szo,V.Value (_,bty,{V.av_default=Some dexp})) ->
               e.p (sprintf "?(%s=%s)" id (ocaml_string_of_expr bty env dexp));
            |`Free (id,szo,av) ->
               e.p (sprintf "~%s" id);
            |`Bound _ |_ -> ()
        ) (def_fvars @ other_fvars);
        indent_fn e (fun e ->
            e.p "env =";
            indent_fn e (fun e ->
                List.iter (function
                  |`Free (id,szo,ty) ->
                     if is_custom_type ty then
                          e.p (sprintf "let %s = %s in (* custom *)" id (ocaml_const_of_id id ty))
                  |_ -> ()
                ) fvars;
                let szs = ref [] in
                List.iter (fun t ->
                    match t with
                    |`Free (id,szo,V.Value ("bit",(V.UInt V.I8),_))
                    |`Bound (id,szo,V.Value ("bit",(V.UInt V.I8),_)) -> ()
                    |`Free (id,szo,v)
                    |`Bound (id,szo,v) -> begin
                       let foldfn = fold_sizes ~dynlenfn:(fun id -> sprintf "%s___len" id) 
                           ~dynclassfn:(fun cid id -> sprintf "%s___len" id) in
                       let _ = match v with
                       |V.Packet (p,_) ->
                         e.p (sprintf "let ___env = sub env (%s) 0 in" (foldfn !szs));
                         e.p (sprintf "let %s = %s.m %s ___env in let %s___len = length ___env in" id p id id);
                       |V.Array (_,V.UInt V.I8,at) ->
                         let needalign,alignamt = match at with
                         |{V.aa_align=Some alval} -> true,(alval/8)
                         |_ -> false,0
                         in
                         let off = foldfn !szs in
                         e.p (sprintf "let %s___len = match %s with " id id);
                         e.p (sprintf "|`Str x -> set_string env (%s) x; String.length x" off);
                         e.p (sprintf "|`Sub fn -> let view = sub env (%s) 0 in fn view; length view" off);
                         e.p (sprintf "|`None -> 0");
                         e.p (sprintf "|`Frag t -> set_view env (%s) t; length t in" off);
                         if needalign then begin
                           e.p (sprintf "let ___al = (%d - (%s___len mod %d)) mod %d in" alignamt id alignamt alignamt);
                           e.p (sprintf "for i = 1 to ___al do");
                           indent_fn e (fun e -> e.p (sprintf "set_byte env ((%s) + %s___len + i) 0" off id));
                           e.p (sprintf "done; let %s___len = %s___len + ___al in" id id);
                         end
                       |V.Class cid ->
                         let off = foldfn !szs in
                         e.p (sprintf "let ___env = sub env (%s) 0 in" off);
                         e.p (sprintf "let %s = Array.init (List.length %s) (fun i -> List.nth %s i) in" id id id);
                         e.p (sprintf "let pos = ref 0 in");
                         e.p (sprintf "let %s = Array.map (fun x ->" id);
                         indent_fn e (fun e ->
                           e.p "let env' = sub ___env !pos 0 in";
                           e.p (sprintf "let __r = %sm x env' in pos := !pos + (length env'); __r" (modname ~sub:env.mods cid));
                         );
                         e.p (sprintf ") %s in" id);
                         e.p (sprintf "let %s___len = !pos in" id);
                       |_ -> () in
                       let n = ocaml_size_of_ty env id szo v in
                       szs := n :: !szs;
                        if Hashtbl.mem env.offsets id then 
                           e.p (sprintf "let %s___offset = %s in" id (foldfn !szs));
                       if Hashtbl.mem env.sizes id then
                           e.p (sprintf "let %s___sizeof = %s in" id (foldfn [n]));
                       end;
                    |_ -> interr "sizes"
                ) fvars;

                let dummys = List.rev (List.fold_left (fun a -> function
                   |`Bound (id,szo,V.Value (_,_,{V.av_bitdummy=true})) ->
                     id :: a
                   |_ -> a) [] fvars)
                in
                let bits = List.rev (List.fold_left (fun a -> function
                   |`Bound (id,szo,(V.Value ("bit",_,at)))
                   |`Free (id,szo,(V.Value ("bit",_,at))) -> begin
                     let _ = match at with
                     |{V.av_value=Some vexp} ->
                        e.p (sprintf "let %s = %s in (* bit bound *)" id (ocaml_string_of_expr (V.UInt V.I16) env vexp));
                        
                     |{V.av_const=Some cexp} ->
                        e.p (sprintf "let %s = %d in (* const bit *)" id (E.to_const_int cexp));
                     |{V.av_variant=Some _} ->
                        e.p (sprintf "let %s = %s_marshal %s in" id id id);
                     |_ ->
                        let mrange = tworaised (must E.to_const_int szo) in
                        e.p (sprintf "if %s < 0 || %s > %d then raise (Bad_packet \"out of range (0 < %s < %d)\");"
                           id id mrange id mrange);
                     in
                     (id,(must E.to_const_int szo),at) :: a
                   end
                   |_ -> a) [] fvars) in
                let bitm = Hashtbl.create 1 in
                let ac = ref 0 in
                List.iter (fun (id,sz,attr) ->
                  let lft = ref sz in
                  let hashadd v = hashtbl_add_list bitm (List.nth dummys (!ac / 8)) v in
                  let rac = !ac mod 8 in
                  let toshift = min sz (8-rac) in
                  let vsr = let x' = sz - toshift in if x' > 0 then sprintf "(%s lsr %d)" id x' else id in
                  let vsl = let x' = 8 - (rac + toshift) in if x' > 0 then sprintf "(%s lsl %d)" vsr x' else vsr in
                  hashadd vsl;
                  ac := !ac + toshift;
                  lft := !lft - toshift;
                  while !lft > 7 do 
                     assert ((!ac mod 8) = 0);
                     let vsr = let x' = sz - 8 - !lft in if x' > 0 then sprintf "(%s lsr %d)" id x' else id in
                     hashadd (sprintf "(%s land %d)" vsr (tworaised 8));
                     lft := !lft - 8;
                     ac := !ac + 8;
                  done;
                  if !lft > 0 then begin
                     let vand = sprintf "(%s land %d)" id (tworaised !lft) in
                     hashadd (sprintf "(%s lsl %d)" vand (8 - !lft));
                     ac := !ac + !lft;
                  end;
                ) bits;
                Hashtbl.iter (fun id vl -> e.p (sprintf "let %s = %s in" id (String.concat " + " vl))) bitm;
                let rec szfn = function
                |`Bound (id,szo,V.Value ("bit",_,_)) :: r 
                |`Free (id,szo,V.Value ("bit",_,_)) :: r  -> szfn r
                  (* this order is important, av_value must be checked before av_const for range expressions *)
                |`Bound (id,szo,(V.Value (_,vb,{V.av_value=Some v}) as vv)) :: r -> begin
                    e.p (sprintf "let %s = %s in (* bound *)" id (ocaml_const_of_native env v vv));
                    szfn r;
                end
                |`Bound (id,szo,(V.Value (vty,vb,{V.av_const=Some v}) as vv)) :: r -> begin
                    e.p (sprintf "let %s = %s in (* const *)" id (ocaml_const_of_native env v vv));
                    szfn r;
                end
                |_ :: r ->
                    szfn r
                |[] -> () in
                szfn fvars;
                List.iter (function
                |`Bound (id,szo,V.Value ("bit",_,_)) 
                |`Free (id,szo,V.Value ("bit",_,_)) -> ()
                |`Free (id,szo,(V.Value(a,b,({V.av_variant=Some _} as c)))) ->
                    e.p (sprintf "let __%s = %s_marshal %s in" id id id);
                    e.p (sprintf "let __%s = %s in" id (ocaml_const_of_id ("__"^id) (V.Value (a,b,{c with V.av_variant=None}))))
                |`Free (id,szo,(V.Class cl)) ->
                    e.p (sprintf "(* %s: class(%s) *)" id (String.concat "." cl));
                |`Free (id,szo,(V.Packet (p,_))) ->
                    e.p (sprintf "(* %s: packet(%s) *)" id p);
                |`Free (id,szo,ty) ->
                    if not (is_custom_type ty) then
                    e.p (sprintf "let %s = %s in" id (ocaml_const_of_id id ty))
                |`Bound _
                |_ -> ()
                ) fvars;
                e.p (sprintf "let __pos = 0 in");
                List.iter (function
                |`Free (id,szo,ty)
                |`Bound (id,szo,ty) -> begin
                    let isvar = function
                    |V.Value (_,_,{V.av_variant=Some _}) -> true
                    |_ -> false in
                    let prfn x sz = e.p (sprintf "let __pos = %s %s%s; __pos + %s in" x (if isvar ty then "__" else "") id sz) in
                    match ty with
                    |V.Value ("bit",V.UInt V.I8,_) -> e.p (sprintf  "(* bit %s *)" id);
                    |V.Value ("byte",V.UInt V.I8,_) -> prfn "set_byte env __pos" "1"
                    |V.Value (_,V.UInt V.I8,_) -> interr "print_marshal"
                    |V.Value (_,V.UInt V.I16,_) -> prfn "set_uint16_be env __pos" "2"; 
                    |V.Value (_,V.UInt V.I32,_) -> prfn "set_uint32_be env __pos" "4";
                    |V.Value (_,V.UInt V.I64,_) -> prfn "set_uint64_be env __pos" "8";
                    |V.Array (_,(V.UInt V.I8),_) |V.Class _ |V.Packet _ ->
                      e.p (sprintf "let __pos = __pos + %s___len in" id);
                    |V.Label -> ()
                    |ty ->
                      e.p (sprintf "let %s = %s env __pos %s%s in" id (custom_type_marshal ty) (if isvar ty then "__" else "") id);
                      e.p (sprintf "let __pos = __pos + %s in" (foldfn1 [ocaml_size_of_ty env id szo ty]))
                end 
                ) fvars;
                e.p "seek env __pos;";
                e.p "{ env; ";
                list_iter_indent e (fun e -> function
                  |`Free (id,szo,V.Array (_,V.UInt V.I8,_))
                  |`Bound (id,szo,V.Array (_,V.UInt V.I8,_)) ->
                     if not (must E.is_const szo) then 
                        e.p (sprintf "%s_length=%s___len;" id id)
                  |`Free (id,szo,V.Packet _)
                  |`Free (id,szo,V.Class _) ->
                     e.p (sprintf "%s=%s;" id id);
                  |`Bound (id,szo,vty) ->
                     if is_custom_type vty && not (custom_is_const_size vty) then e.p (sprintf "%s=%s;" id id);
                  |`Free (id,szo,vty) ->
                     if is_custom_type vty then e.p (sprintf "%s=%s;" id id);
                  |_ -> ()
                ) fvars;
                e.p "}";
            );
            e.nl ();
         );
         e.p (sprintf "let m (x:(t->o)) env = x env");
    in
    print_variant_types env e l;
    fn env e env.mods l
    
let print_statecalls e pname xs =
    let scs = Hashtbl.create 1 in
    let rec fn mods = function
    |V.S_class (id, idty, l) :: r ->
        List.iter (fun (ex,bid,gu,xs) ->
            let bidstr = E.to_const_string bid in
            fn (bidstr::mods) (xs@r)
        ) l
    |V.S_array (id,sz,xs) :: r ->
        fn (id::mods) [];
        fn mods r
    |_ :: r -> fn mods r
    |[] ->
        let scn = String.concat "_" (List.rev_map String.capitalize (mods@[pname])) in
        Hashtbl.replace scs scn ()
    in fn [] xs;
    e.p "type statecalls = [";
    indent_fn e (fun e -> Hashtbl.iter (fun k () -> e.p (sprintf "|`Transmit_%s |`Receive_%s" k k)) scs);
    e.p "]"
        
let marshal e p (env,txs) =
    e.p "open OS.Istring";
    e.p "exception Bad_packet of string";
    e.nl ();
    print_struct {env with mods=[]; pname=p.S.name} e txs;
    e.nl ();
    print_unmarshal {env with mods=[]; pname=p.S.name} e txs;
