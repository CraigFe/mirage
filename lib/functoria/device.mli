(*
 * Copyright (c) 2013-2020 Thomas Gazagnaire <thomas@gazagnaire.org>
 * Copyright (c) 2013-2020 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2015-2020 Gabriel Radanne <drupyog@zoho.com>
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
 *)

(** Signature for functoria devices. A [device] is a module implementation which
    contains a runtime state which can be set either at configuration time (by
    the application builder) or at runtime, using command-line arguments. *)

type ('a, 'b) t
(** The type for devices whose runtime state is of type ['a] and having extra
    data-dependencies of type ['b]. *)

val module_type : ('a, 'b) t -> 'a Type.t
(** [module_type t] is [t]'s module type. *)

val module_name : ('a, 'b) t -> string
(** [module_name t] is [t]'s module name. *)

val packages : ('a, 'b) t -> Package.t list Key.value
(** [packages t] is the list of OPAM packages that are needed by [t].*)

val install : ('a, 'b) t -> Info.t -> Install.t Key.value
(** [install t i] is the list of files installed by [t], using the build
    information [i]. *)

val extra_deps : ('a, 'b) t -> 'b list
(** [extra_deps t] is the list of dependencies that be initialized before
    running the code generated by [connect t]. *)

val id : ('a, 'b) t -> int
(** [id t] is [t]'s unique identifier. Freshly generated for each call to {!v}. *)

val pp : 'b Fmt.t -> ('a, 'b) t Fmt.t
(** [pp pp_dep] is the pretty-printer for devices, using [pp_dep] to
    pretty-print the extra data-dependencies. *)

val equal : ('a, 'b) t -> ('c, 'd) t -> bool
(** [equal] is the equality function for devices. *)

val hash : ('a, 'b) t -> int
(** [hash t] is [t]'s hash. *)

(** {1 Effects} *)

type 'a code = string
(** The type for fragments of code of type ['a]. *)

val connect : ('a, 'b) t -> Info.t -> string -> string list -> 'a code
(** [connect t info impl_name args] is the code to execute in order to create a
    new state (usually calling [<module_name t>.connect]) with the arguments
    [args], in the context of the project information [info]. The freshly
    created state will be made available in [var_name t] *)

val configure : ('a, 'b) t -> Info.t -> unit Action.t
(** [configure t info] runs [t]'s configuration hooks. During the configuration
    phase, [packages t] might not yet be installed yet. The code might involve
    generating more OCaml code, running shell scripts, etc. *)

val build : ('a, 'b) t -> Info.t -> unit Action.t
(** [build t info] runs the build hooks for [t] the device. During the build
    phase, you can rely on every [packages t] to be installed. The code might
    involve generating more OCaml code (crunching directories), running shell
    scripts, etc. *)

val clean : ('a, 'b) t -> Info.t -> unit Action.t
(** [clean t info] runs [t]'s clean-up hooks. *)

val keys : ('a, 'b) t -> Key.t list
(** [keys t] is the list of command-line keys which can be used to configure
    [t]. *)

val start : string -> string list -> 'a code
(** [start impl_name args] is the code [<impl_name>.start <args>]. *)

(** {1 Constructors} *)

val v :
  ?packages:Package.t list ->
  ?packages_v:Package.t list Key.value ->
  ?install:(Info.t -> Install.t) ->
  ?install_v:(Info.t -> Install.t Key.value) ->
  ?keys:Key.t list ->
  ?extra_deps:'b list ->
  ?connect:(Info.t -> string -> string list -> 'a code) ->
  ?configure:(Info.t -> unit Action.t) ->
  ?build:(Info.t -> unit Action.t) ->
  ?clean:(Info.t -> unit Action.t) ->
  string ->
  'a Type.t ->
  ('a, 'b) t

val extend :
  ?packages:Package.t list ->
  ?packages_v:Package.t list Key.value ->
  ?pre_configure:(Info.t -> unit Action.t) ->
  ?post_configure:(Info.t -> unit Action.t) ->
  ?pre_build:(Info.t -> unit Action.t) ->
  ?post_build:(Info.t -> unit Action.t) ->
  ?pre_clean:(Info.t -> unit Action.t) ->
  ?post_clean:(Info.t -> unit Action.t) ->
  ('a, 'b) t ->
  ('a, 'b) t
