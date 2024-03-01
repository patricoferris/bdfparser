type t

val create: string -> (t, string) result

val name: t -> string

val bdf_version: t -> float

val version: t -> int

module Glyph : sig
    type t

    val name: t -> string
    (** [name glyph] Returns the name in the font file of the specified glyph. *)

    val bbox: t -> (int * int * int * int)
    (** [bbox glyph] The underlying font bbox parameter. *)

    val dwidth: t -> (int * int)
    (** [dwidth glyph] The underlying font dwidth parameter. *)

    val dimensions: t -> (int * int * int * int)
    (** [dimensions glyph] Returns the width and height of the specified glyph, along with the x and y offsets from the drawing location to allow for descenders etc. *)

    val bitmap: t -> bytes
    (** [bitmap glyph] Renders a glyph to a series of bytes. The data is 1 bit per pixel,
        as a series of bytes per row, padded to the appropriate next byte boundary.
        *)
end

val glyph_count: t -> int
    (** [glyph_count font] Returns a count of how many glyphs are in the font. *)

val glyph_of_char: t -> Uchar.t -> Glyph.t option
(** [glyph_of_char font char] Gets the glyph that maps to a given character in the font,
    or None if that character doesn't have an entry. *)

(** {2 Parser and Lexer} *)

module Parser = Parser
module Lexer = Lexer