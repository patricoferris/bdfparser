module Glyph = struct
type t = {
  name : string;
  encoding : int;
  swidth : int * int;
  swidth1 : int * int;
  dwidth : int * int;
  dwidth1 : int * int ;
  vvector : int * int ;
  bounding_box : int * int * int * int ;
  bitmap : bytes;
}

let default = {
  name = "" ;
  encoding = 0 ;
  swidth = (0, 0) ;
  swidth1 = (0, 0) ;
  dwidth = (0, 0) ;
  dwidth1 = (0, 0) ;
  vvector = (0, 0) ;
  bounding_box = (0, 0, 0, 0) ;
  bitmap = Bytes.empty ;
}

let name (g : t) : string =
  g.name

let bbox (g : t) : (int * int * int * int) =
  g.bounding_box

let dwidth (g : t) : (int * int) =
  g.dwidth

let dimensions (g : t) : (int * int * int * int) =
  (* This is totes wrong, but enough to bootstrap with I think for basic western chars *)
  let x, _ = g.dwidth in
  let _, y, ox, oy = g.bounding_box in
  (x, y, ox, oy)

let bitmap (g : t) : bytes =
  g.bitmap
end

type t = {
  version : float ;
  name : string ;
  size : int * int * int ;
  bounding_box : int * int * int * int ;
  content_version : int ;
  metric_set : int ;
  properties : (string * Types.property_val) list;
  glyphs : Glyph.t array;
  map: (Uchar.t * int) list;
}

let glyph_count t =
  Array.length t.glyphs

let glyph_of_char (font : t) (u : Uchar.t) : Glyph.t option =
  match (List.assoc_opt u font.map) with
  | None -> None
  | Some index -> (
    match ((index >= 0) && (index < Array.length font.glyphs)) with
    | false -> None
    | true -> Some font.glyphs.(index)
  )

let default_t = {
  version = 0. ;
  name = "" ;
  size = (0, 0, 0) ;
  bounding_box = (0, 0, 0, 0) ;
  content_version = 0 ;
  metric_set = 0 ;
  properties = [] ;
  glyphs = [||] ;
  map = [] ;
}

let innerchar_to_glyph (ic : Types.char_property_val list) : Glyph.t =
  List.fold_left (fun (acc : Glyph.t ) (item : Types.char_property_val) : Glyph.t  ->
    match item with
    | `CharName n -> { acc with name=n }
    | `Encoding e -> { acc with encoding=e }
    | `SWidth s -> { acc with swidth=s }
    | `DWidth s -> { acc with dwidth=s }
    | `SWidth1 s -> { acc with swidth1=s }
    | `DWidth1 s -> { acc with dwidth1=s }
    | `VVector v -> { acc with vvector=v }
    | `BBox b -> { acc with bounding_box=b }
    | `Bitmap d -> (
      (* this is poor, in that I currently assume the bbox has come first. In the spec the definition of
         the bitmap field depends on the values in bbox, but it strictly doesn't say bbox must come first
         so at some point we should do better, but for bootstrapping purposes I'm going to assume bbox
         is valid by this point. *)
      let w, _, _, _ = acc.bounding_box in
      (* TODO we should asssert length of bitmap is same as h in bbox as per spec *)
      let bytes_per_line = Int.of_float (ceil ((Float.of_int w) /. 8.)) in
      let h = List.length d in
      let bitmap = Bytes.create (h * bytes_per_line) in
      List.iteri (fun r v ->
        for c = 0 to (bytes_per_line - 1) do
          Bytes.set bitmap ((r * bytes_per_line) + c) (char_of_int ((Int.shift_right v (8 * c)) land 0xFF))
        done
      ) d;
      { acc with bitmap = bitmap }
    )
  ) Glyph.default ic


let create (filename : string) : (t, string) result =
  let ast = In_channel.with_open_text filename (fun ic ->
    let lexbuf = Lexing.from_channel ic in
    Parser.prog Lexer.read lexbuf
  ) in
  match ast with
  | None -> (Error "No file")
  | Some ast -> (
    Ok (
      let fnt = List.fold_left (fun (acc : t) (item : Types.header) : t ->
        match item with
        | `Version v -> { acc with version=v }
        | `Size s -> { acc with size=s }
        | `FontName n -> { acc with name=n }
        | `BoundingBox b -> { acc with bounding_box=b }
        | `Comment _ -> acc
        | `Chars _ -> acc
        | `MetricSet s -> { acc with metric_set=s }
        | `ContentVersion c -> { acc with content_version=c }
        | `Properties p -> { acc with properties=(List.concat [acc.properties ; p]) }
        | `Char c -> (
          let g = innerchar_to_glyph c in
          { acc with glyphs=(Array.of_list (g :: (Array.to_list acc.glyphs)))}
        )
        | `Noop -> acc
        ) default_t ast
      in
      (* having built it, now work out the lookup map *)
      let map = Array.mapi (fun i g -> (Uchar.of_int g.Glyph.encoding, i)) fnt.glyphs in
      { fnt with map=(Array.to_list map) }
    )
  )

let name t =
  t.name

let bdf_version t =
  t.version

let version t =
  t.content_version

module Parser = Parser
module Lexer = Lexer