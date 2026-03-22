///|
pub struct Decoder[I, E, O]((I) -> Result[O, Array[E]])

///|
pub type Validator[I, E] = Decoder[I, E, Unit]

///|
pub fn[I, E, O] run(
  decoder : Decoder[I, E, O],
  input : I,
) -> Result[O, Array[E]] {
  let Decoder(decode) = decoder
  input |> decode
}

///|
pub fn[I, E, O] errors(decoder : Decoder[I, E, O], input : I) -> Array[E] {
  match run(decoder, input) {
    Err(errors) => errors
    Ok(_) => []
  }
}

///|
pub fn[I, E, O] custom(decode : (I) -> Result[O, Array[E]]) -> Decoder[I, E, O] {
  Decoder(decode)
}

///|
/// ```mbt check
/// test "identity" {
///   let str_identity : Decoder[String, String, String] = identity()
///   let int_identity : Decoder[Int, String, Int] = identity()
///   assert_eq(str_identity |> run("foo"), Ok("foo"))
///   assert_eq(int_identity |> run(34), Ok(34))
/// }
/// ```
pub fn[I, E] identity() -> Decoder[I, E, I] {
  custom(x => Ok(x))
}

///|
/// ```mbt check
/// test "always" {
///   assert_eq(always("foo") |> run("bar"), Ok("foo"))
///   assert_eq(always(34) |> run(23), Ok(34))
/// }
/// ```
pub fn[I, O] always(value : O) -> Decoder[I, Unit, O] {
  custom(_ => Ok(value))
}

///|
/// ```mbt check
/// test "fail" {
///   assert_eq(fail("error") |> run("foo"), Err(["error"]))
///   assert_eq(fail("error") |> run((Ok(34) : Result[Int, Unit])), Err(["error"]))
/// }
/// ```
pub fn[I, E] fail(error : E) -> Decoder[I, E, Unit] {
  custom(_ => Err([error]))
}

///|
/// ```mbt check
/// test "int" {
///   assert_eq(int("Invalid") |> run("foo"), Err(["Invalid"]))
///   assert_eq(int("Invalid") |> run("34"), Ok(34))
///   assert_eq(int("Invalid") |> run("34.3"), Err(["Invalid"]))
///   assert_eq(int("Invalid") |> run("34e3"), Err(["Invalid"]))
/// }
/// ```
pub fn[E] int(error : E) -> Decoder[String, E, Int] {
  custom(x => (try? @strconv.parse_int(x)) |> Result::map_err(_ => [error]))
}

///|
/// ```mbt check
/// test "double" {
///   assert_eq(double("Invalid") |> run("foo"), Err(["Invalid"]))
///   assert_eq(double("Invalid") |> run("34"), Ok(34))
///   assert_eq(double("Invalid") |> run("34.3"), Ok(34.3))
///   assert_eq(double("Invalid") |> run("34e3"), Ok(34000))
/// }
/// ```
pub fn[E] double(error : E) -> Decoder[String, E, Double] {
  custom(x => (try? @strconv.parse_double(x)) |> Result::map_err(_ => [error]))
}

///|
/// ```mbt check
/// test "min_bound" {
///   let decoder = min_bound("Too small", 10)
///   assert_eq(decoder |> run(2), Err(["Too small"]))
///   assert_eq(decoder |> run(9), Err(["Too small"]))
///   assert_eq(decoder |> run(10), Ok(()))
///   assert_eq(decoder |> run(15), Ok(()))
/// }
/// ```
pub fn[I : Compare, E] min_bound(error : E, bound : I) -> Validator[I, E] {
  custom(x => if x >= bound { Ok(()) } else { Err([error]) })
}

///|
/// ```mbt check
/// test "max_bound" {
///   let decoder = max_bound("Too large", 10)
///   assert_eq(decoder |> run(2), Ok(()))
///   assert_eq(decoder |> run(10), Ok(()))
///   assert_eq(decoder |> run(11), Err(["Too large"]))
///   assert_eq(decoder |> run(15), Err(["Too large"]))
/// }
/// ```
pub fn[I : Compare, E] max_bound(error : E, bound : I) -> Validator[I, E] {
  custom(x => if x <= bound { Ok(()) } else { Err([error]) })
}

///|
/// ```mbt check
/// test "min_length" {
///   let decoder = min_length("Too short", 10)
///   assert_eq(decoder |> run("short"), Err(["Too short"]))
///   assert_eq(decoder |> run("012345678"), Err(["Too short"]))
///   assert_eq(decoder |> run("0123456789"), Ok(()))
///   assert_eq(decoder |> run("01234567890abcde"), Ok(()))
/// }
/// ```
pub fn[E] min_length(error : E, bound : Int) -> Validator[String, E] {
  custom(x => if x.length() >= bound { Ok(()) } else { Err([error]) })
}

///|
/// ```mbt check
/// test "max_length" {
///   let decoder = max_length("Too long", 10)
///   assert_eq(decoder |> run("short"), Ok(()))
///   assert_eq(decoder |> run("0123456789"), Ok(()))
///   assert_eq(decoder |> run("0123456789a"), Err(["Too long"]))
///   assert_eq(decoder |> run("01234567890abcde"), Err(["Too long"]))
/// }
/// ```
pub fn[E] max_length(error : E, bound : Int) -> Validator[String, E] {
  custom(x => if x.length() <= bound { Ok(()) } else { Err([error]) })
}

///|
/// ```mbt check
/// test "assert" {
///   let validator1 = min_bound("TooSmall", 3)
///   let validator2 = max_bound("TooBig", 6)
///   let decoder = int("Invalid") |> validate(validator1) |> validate(validator2)
///
///   assert_eq(decoder |> run("foo"), Err(["Invalid"]))
///   assert_eq(decoder |> run("2"), Err(["TooSmall"]))
///   assert_eq(decoder |> run("32"), Err(["TooBig"]))
/// }
/// ```
pub fn[I, E, O] validate(
  decoder : Decoder[I, E, O],
  validator : Validator[O, E],
) -> Decoder[I, E, O] {
  custom(x => {
    let Decoder(decode) = decoder
    decode(x) |> Result::bind(y => run(validator, y) |> Result::map(_ => y))
  })
}

///|
/// ```mbt check
/// test "lift" {
///   struct Form {
///     field1 : String
///     _field2 : String
///   }
///   let decoder = lift((form : Form) => form.field1, min_length("Too short", 5))
///
///   assert_eq(
///     decoder |> run(Form::{ field1: "foo", _field2: "barbar" }),
///     Err(["Too short"]),
///   )
///   assert_eq(
///     decoder |> run(Form::{ field1: "foofoo", _field2: "barbar" }),
///     Ok(()),
///   )
/// }
/// ```
pub fn[I, J, E, O] lift(
  f : (J) -> I,
  decoder : Decoder[I, E, O],
) -> Decoder[J, E, O] {
  custom(x => f(x) |> decoder)
}

///|
/// ```mbt check
/// test "when" {
///   struct Form {
///     enable_check : Bool
///     input : String
///   }
///   let validator = when(
///     (form : Form) => form.enable_check,
///     lift((form : Form) => form.input, min_length("TooShort", 3)),
///   )
///
///   assert_eq(
///     validator |> run({ enable_check: true, input: "f" }),
///     Err(["TooShort"]),
///   )
///   assert_eq(validator |> run({ enable_check: false, input: "f" }), Ok(()))
///   assert_eq(validator |> run({ enable_check: true, input: "foo" }), Ok(()))
/// }
/// ```
pub fn[I, E] when(
  predicate : (I) -> Bool,
  validator : Validator[I, E],
) -> Validator[I, E] {
  custom(x => if predicate(x) { validator(x) } else { Ok(()) })
}

///|
/// ```mbt check
/// test "unless" {
///   struct Form {
///     skip_check : Bool
///     input : String
///   }
///   let validator = unless(
///     (form : Form) => form.skip_check,
///     lift((form : Form) => form.input, min_length("TooShort", 3)),
///   )
///
///   assert_eq(
///     validator |> run({ skip_check: false, input: "f" }),
///     Err(["TooShort"]),
///   )
///   assert_eq(validator |> run({ skip_check: false, input: "fff" }), Ok(()))
///   assert_eq(validator |> run({ skip_check: true, input: "f" }), Ok(()))
///   assert_eq(validator |> run({ skip_check: true, input: "fff" }), Ok(()))
/// }
/// ```
pub fn[I, E] unless(
  predicate : (I) -> Bool,
  validator : Validator[I, E],
) -> Validator[I, E] {
  when(x => !predicate(x), validator)
}

///|
/// ```mbt check
/// test "map" {
///   let decoder = int("Invalid") |> map(x => x + 5)
///
///   assert_eq(decoder |> run("3"), Ok(8))
///   assert_eq(decoder |> run("10"), Ok(15))
///   assert_eq(decoder |> run("str"), Err(["Invalid"]))
/// }
/// ```
pub fn[I, E, A, B] map(
  decoder : Decoder[I, E, A],
  f : (A) -> B,
) -> Decoder[I, E, B] {
  custom(x => decoder(x) |> Result::map(f))
}

///|
pub fn[I, O, F] top(f : F) -> Decoder[I, O, F] {
  custom(_ => Ok(f))
}

///|
pub fn[I, E, A, B] field(
  g : Decoder[I, E, (A) -> B],
  f : Decoder[I, E, A],
) -> Decoder[I, E, B] {
  custom(x => {
    match (g(x), f(x)) {
      (Err(g_err), Err(f_err)) => Err(g_err + f_err)
      (Err(g_err), Ok(_)) => Err(g_err)
      (Ok(g_ok), Ok(f_ok)) => Ok(g_ok(f_ok))
      (Ok(_), Err(f_err)) => Err(f_err)
    }
  })
}

///|
/// ```mbt check
/// test "map2" {
///   struct Form {
///     str : String
///     int : String
///   }
///   struct Decoded {
///     str : String
///     int : Int
///   } derive(Show, Eq)
///   let str_decoder = identity() |> validate(min_length("TooShort", 5))
///   let int_decoder = int("InvalidInt")
///   let form_decoder = map2(
///     str => int => Decoded::{ str, int },
///     lift((form : Form) => form.str, str_decoder),
///     lift((form : Form) => form.int, int_decoder),
///   )
///
///   assert_eq(
///     form_decoder |> run(Form::{ str: "foo", int: "bar" }),
///     Err(["TooShort", "InvalidInt"]),
///   )
///   assert_eq(
///     form_decoder |> run(Form::{ str: "foo", int: "23" }),
///     Err(["TooShort"]),
///   )
///   assert_eq(
///     form_decoder |> run(Form::{ str: "foobar", int: "bar" }),
///     Err(["InvalidInt"]),
///   )
///   assert_eq(
///     form_decoder |> run(Form::{ str: "foobar", int: "23" }),
///     Ok(Decoded::{ str: "foobar", int: 23 }),
///   )
/// }
/// ```
pub fn[A, B, I, E, O] map2(
  f : (A) -> (B) -> O,
  d1 : Decoder[I, E, A],
  d2 : Decoder[I, E, B],
) -> Decoder[I, E, O] {
  top(f) |> field(d1) |> field(d2)
}

///|
pub fn[A, B, C, I, E, O] map3(
  f : (A) -> (B) -> (C) -> O,
  d1 : Decoder[I, E, A],
  d2 : Decoder[I, E, B],
  d3 : Decoder[I, E, C],
) -> Decoder[I, E, O] {
  top(f) |> field(d1) |> field(d2) |> field(d3)
}

///|
pub fn[A, B, C, D, I, E, O] map4(
  f : (A) -> (B) -> (C) -> (D) -> O,
  d1 : Decoder[I, E, A],
  d2 : Decoder[I, E, B],
  d3 : Decoder[I, E, C],
  d4 : Decoder[I, E, D],
) -> Decoder[I, E, O] {
  top(f) |> field(d1) |> field(d2) |> field(d3) |> field(d4)
}

///|
pub fn[A, B, C, D, F, I, E, O] map5(
  f : (A) -> (B) -> (C) -> (D) -> (F) -> O,
  d1 : Decoder[I, E, A],
  d2 : Decoder[I, E, B],
  d3 : Decoder[I, E, C],
  d4 : Decoder[I, E, D],
  d5 : Decoder[I, E, F],
) -> Decoder[I, E, O] {
  top(f) |> field(d1) |> field(d2) |> field(d3) |> field(d4) |> field(d5)
}

///|
pub fn[E1, E2, I, O] map_error(
  f : (E1) -> E2,
  decoder : Decoder[I, E1, O],
) -> Decoder[I, E2, O] {
  custom(x => decoder(x) |> Result::map_err(err => err |> Array::map(f)))
}
