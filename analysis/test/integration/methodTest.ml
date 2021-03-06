(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)


open OUnit2
open IntegrationTest


let test_check_method_returns _ =
  assert_type_errors
    {|
      def foo(input: str) -> int:
          return input.lower()
    |}
    ["Incompatible return type [7]: Expected `int` but got `str`."];

  assert_type_errors
    {|
      def foo(input: str) -> int:
          return input.lower().upper()
    |}
    ["Incompatible return type [7]: Expected `int` but got `str`."];

  assert_type_errors
    {|
      def foo() -> int:
          return ''.upper()
    |}
    ["Incompatible return type [7]: Expected `int` but got `str`."]


let test_check_method_parameters _ =
  assert_type_errors
    {|
      def foo(input: str) -> None:
        input.substr(1)
    |}
    [];

  assert_type_errors
    {|
      def foo(input: str) -> None:
        input.substr('asdf')
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `str.substr` but got `str`.";
    ];

  assert_type_errors
    {|
      def foo(a: str, b: str) -> None:
        pass
      def bar() -> None:
        foo(1, 2)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `str` for 1st anonymous parameter to call `foo` but got `int`.";
    ];

  assert_type_errors
    {|
      def foo(input: str) -> str:
        return input.substr('asdf')
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `str.substr` but got `str`.";
    ];

  assert_type_errors
    {|
      def foo(input: str) -> None:
        input.substr('asdf').substr('asdf')
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `str.substr` but got `str`.";
    ];

  assert_type_errors
    {|
      def foo(input: str) -> None:
        input + 1
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `int.__radd__` but got `str`."];

  assert_type_errors
    {|
      def foo(input: str) -> str:
        return input.__sizeof__()
    |}
    ["Incompatible return type [7]: Expected `str` but got `int`."];

  assert_type_errors
    {|
      class Foo:
        def bar(self) -> None:
          def baz(x: int) -> int:
            return x
    |}
    [];

  assert_type_errors
    {|
      class Foo:
        def bar(x: int) -> int:
          return x
    |}
    [
      "Incompatible variable type [9]: x is declared to have type `int` but is used as type `Foo`.";
    ]


let test_check_abstract_methods _ =
  assert_type_errors
    {|
      @abstractmethod
      def abstract()->int:
        pass
    |}
    [];

  assert_type_errors
    {|
      @abc.abstractproperty
      def abstract()->int:
        pass
    |}
    []


let test_check_behavioral_subtyping _ =
  (* Strengthened postcondition. *)
  assert_type_errors
    {|
      class Foo():
        def foo() -> int: ...
      class Bar(Foo):
        def foo() -> float: return 1.0
    |}
    [
      "Inconsistent override [15]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Returned type `float` is not a subtype of the overridden return `int`."
    ];

  assert_type_errors
    {|
      class Foo():
        def foo() -> float: ...
      class Bar(Foo):
        def foo() -> int: return 1
    |}
    [];
  assert_type_errors
    {|
      class Foo():
        def foo() -> int: ...
      class Bar(Foo):
        def foo() -> None: pass
    |}
    [
      "Inconsistent override [15]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Returned type `None` is not a subtype of the overridden return `int`."
    ];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def foo() -> _T: ...
      class Bar(Foo[float]):
        def foo() -> str: return ""
    |}
    [
      "Inconsistent override [15]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Returned type `str` is not a subtype of the overridden return `float`."
    ];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def foo() -> _T: ...
      class Bar(Foo[float]):
        def foo() -> int: return 1
    |}
    [];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def foo() -> _T: ...
      class Passthrough(Foo[_T]): ...
      class Bar(Passthrough[float]):
        def foo() -> str: return ""
    |}
    [
      "Inconsistent override [15]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Returned type `str` is not a subtype of the overridden return `float`."
    ];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def foo() -> _T: ...
      class Passthrough(Foo[_T]): ...
      class Bar(Passthrough[float]):
        def foo() -> int: return 1
    |}
    [];

  (* Missing annotations. *)
  assert_type_errors
    ~strict:false
    ~debug:false
    {|
      class Foo():
        def foo() -> int: ...
      class Bar(Foo):
        def foo(): pass
    |}
    [
      "Inconsistent override [15]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "The overriding method is not annotated but should return a subtype of `int`.";
    ];

  (* Starred arguments. *)
  assert_type_errors
    {|
      class C:
        def f(self, *args: int) -> None: ...
      class D(C):
        def f(self, *args: int) -> None: ...
    |}
    [];

  (* Keyword arguments. *)
  assert_type_errors
    {|
      class C:
        def f(self, **kwargs: str) -> None: ...
      class D(C):
        def f(self, **kwargs: str) -> None: ...
    |}
    [];

  (* TODO(T29679691): We should also warn when parameter annotations are missing. *)
  assert_type_errors
    ~strict:false
    {|
      class Foo():
        def foo(input: int) -> int: ...
      class Bar(Foo):
        def foo(input) -> int: ...
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar("T", bound=int)
      class Foo():
        def foo(self, x: T) -> str:
          return ""
      class Bar(Foo[str]):
        def foo(self, x: str) -> str:
          return x
    |}
    [
      "Inconsistent override [14]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Parameter of type `str` is not a supertype of the overridden parameter " ^
      "`Variable[T (bound to int)]`.";
    ];
  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class Foo(typing.Generic[T]):
        def foo(self) -> T:
          return ""
      class Bar(Foo[int]):
        def foo(self) -> int:
          return 1
      class BarTwo(Foo[None]):
        def foo(self) -> None:
          pass
    |}
    [];

  assert_type_errors ~show_error_traces:true
    {|
      class Foo():
        def bar(self, x: int) -> int:
          return 1
      class Bar(Foo):
        def bar(self, x: int) -> typing.Union[str, int]:
          return 1
    |}
    [
      "Inconsistent override [15]: `Bar.bar` overrides method defined in `Foo` " ^
      "inconsistently. Returned type `typing.Union[int, str]` is not a subtype " ^
      "of the overridden return `int`."
    ];

  (* Decorators are applied. *)
  assert_type_errors
    {|
      class Foo():
        @contextlib.contextmanager
        def foo() -> typing.Generator[int, None, None]: ...
      class Bar():
        @contextlib.contextmanager
        def foo() -> typing.Generator[int, None, None]: ...
    |}
    [];

  (* Weakened precondition. *)
  assert_type_errors
    {|
      class Foo():
        def foo(self, a: float) -> None: ...
      class Bar(Foo):
        def foo(self, a: int) -> None: pass
    |}
    [
      "Inconsistent override [14]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Parameter of type `int` is not a supertype of the overridden parameter `float`."
    ];
  assert_type_errors
    {|
      class Foo():
        def foo(self, a) -> None: ...
      class Bar(Foo):
        def foo(self, ) -> None: pass
    |}
    [
      "Inconsistent override [14]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Could not find parameter `a` in overriding signature."
    ];
  assert_type_errors
    {|
      class Foo():
        def foo(self, a: int) -> None: ...
      class Bar(Foo):
        def foo(self, a) -> None: pass
    |}
    ["Missing parameter annotation [2]: Parameter `a` has no type specified."];
  assert_type_errors
    {|
      class Foo():
        def foo(self, ) -> None: ...
      class Bar(Foo):
        def foo(self, a) -> None: pass
    |}
    ["Missing parameter annotation [2]: Parameter `a` has no type specified."];
  assert_type_errors
    {|
      class Foo():
        def foo(self, a) -> None: ...
      class Bar(Foo):
        def foo(self, a: int) -> None: pass
    |}
    [];
  assert_type_errors
    {|
      class Foo():
        def foo(self, a: int) -> None: pass
      class Bar(Foo):
        def foo(self, b: int) -> None: pass
    |}
    [
      "Inconsistent override [14]: `Bar.foo` overrides method defined in `Foo` inconsistently. " ^
      "Could not find parameter `a` in overriding signature."
    ];
  assert_type_errors
    {|
      class Foo():
        def foo(self, a: int) -> None: pass
      class Bar(Foo):
        def foo(self, _a: int) -> None: pass
    |}
    [];
  assert_type_errors ~show_error_traces:true
    {|
      class Foo():
        def bar(self, x: typing.Union[str, int]) -> None:
          pass
      class Bar(Foo):
        def bar(self, x: int) -> None:
          pass
    |}
    [
      "Inconsistent override [14]: `Bar.bar` overrides method defined in `Foo` " ^
      "inconsistently. Parameter of type `int` is not a " ^
      "supertype of the overridden parameter `typing.Union[int, str]`."
    ];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def bar(self, x: typing.Union[str, _T]) -> None:
          pass
      class Bar(Foo[float]):
        def bar(self, x: typing.Union[str, int]) -> None:
          pass
    |}
    [
      "Inconsistent override [14]: `Bar.bar` overrides method defined in `Foo` inconsistently. " ^
      "Parameter of type `typing.Union[int, str]` is not a supertype " ^
      "of the overridden parameter `typing.Union[float, str]`."
    ];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def bar(self, x: typing.Union[str, _T]) -> None:
          pass
      class Bar(Foo[int]):
        def bar(self, x: typing.Union[str, float]) -> None:
          pass
    |}
    [];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def bar(self, x: typing.Union[str, _T]) -> None:
          pass
      class Passthrough(Foo[_T]): ...
      class Bar(Passthrough[float]):
        def bar(self, x: typing.Union[str, int]) -> None:
          pass
    |}
    [
      "Inconsistent override [14]: `Bar.bar` overrides method defined in `Foo` inconsistently. " ^
      "Parameter of type `typing.Union[int, str]` is not a supertype " ^
      "of the overridden parameter `typing.Union[float, str]`."
    ];
  assert_type_errors
    {|
      _T = typing.TypeVar('_T')
      class Foo(Generic[_T]):
        def bar(self, x: typing.Union[str, _T]) -> None:
          pass
      class Passthrough(Foo[_T]): ...
      class Bar(Passthrough[int]):
        def bar(self, x: typing.Union[str, float]) -> None:
          pass
    |}
    [];

  (* A leading underscore indicates parameters are unused; they should still be recognized *)
  assert_type_errors
    {|
      class Foo:
          def bar(self, _x: int) -> str:
              return ""
      class Bar(Foo):
          def bar(self, x: int) -> str:
              return ""
    |}
    [];
  assert_type_errors
    {|
      class Foo:
          def bar(self, _x: int) -> str:
              return ""
      class Baz(Foo):
          def bar(self, _x: int) -> str:
              return ""
    |}
    [];
  assert_type_errors
    {|
      class Foo:
          def bar(self, x: int) -> str:
              return ""
      class Bar(Foo):
          def bar(self, _x: int) -> str:
              return ""
    |}
    [];
  assert_type_errors
    {|
      class Foo:
          def bar(self, _y: int) -> str:
              return ""
      class Bar(Foo):
          def bar(self, x: int) -> str:
              return ""
    |}
    [
      "Inconsistent override [14]: `Bar.bar` overrides method defined in `Foo` " ^
      "inconsistently. Could not find parameter `y` in overriding signature."
    ];

  (* Don't warn on constructors or class methods. *)
  assert_type_errors
    {|
      class Foo():
        def __init__(self, a: float) -> None: ...
      class Bar(Foo):
        def __init__(self, a: int) -> None: pass
    |}
    [];
  assert_type_errors
    {|
      class Foo():
        @classmethod
        def foo(cls, a: float) -> None: ...
      class Bar(Foo):
        @classmethod
        def foo(cls, a: int) -> None: pass
    |}
    [];

  (* Don't warn on dunder methods. *)
  assert_type_errors
    {|
      class Foo():
        def __dunder__(self, a: float) -> None: ...
      class Bar(Foo):
        def __dunder__(self, a: int) -> None: pass
    |}
    [];

  (* Dunder methods must end with dunder. *)
  assert_type_errors
    {|
      class Foo():
        def __f(self, a: float) -> None: ...
      class Bar(Foo):
        def __f(self, a: int) -> None: pass
    |}
    [
      "Inconsistent override [14]: `Bar.__f` overrides method defined in `Foo` inconsistently. " ^
      "Parameter of type `int` is not a supertype of the overridden parameter `float`.";
    ];

  (* Weakening of object precondition is not possible. *)
  assert_type_errors
    {|
      class Foo():
        def __eq__(self, o: object) -> bool: ...
      class Bar(Foo):
        def __eq__(self, other) -> bool: ...
    |}
    [];

  (* Ensure that our preprocessing doesn't clobber starred argument names. *)
  assert_type_errors
    {|
      class Foo():
        def foo( **kwargs) -> int: ...
      class Bar(Foo):
        def foo( **kwargs) -> int: ...
    |}
    [];

  (* Ignore anything involving `Any`. *)
  assert_type_errors
    ~debug:false
    {|
      class Foo():
        def __eq__(self, o: typing.Any) -> typing.Any: ...
      class Bar(Foo):
        def __eq__(self, o: int) -> int: pass
    |}
    [];

  (* Overrides when both *args and **kwargs exist are not inconsistent. *)
  assert_type_errors
    ~debug:false
    {|
      class Foo():
        def f(self, a: float) -> None: ...
      class Bar(Foo):
        def f(self, *args: typing.Any) -> None: pass
    |}
    [
      "Inconsistent override [14]: `Bar.f` overrides method defined in `Foo` inconsistently. " ^
      "Could not find parameter `a` in overriding signature.";
    ];
  assert_type_errors
    ~debug:false
    {|
      class Foo():
        def f(self, b: int) -> None: ...
      class Bar(Foo):
        def f(self, **kwargs: typing.Any) -> None: pass
    |}
    [
      "Inconsistent override [14]: `Bar.f` overrides method defined in `Foo` inconsistently. " ^
      "Could not find parameter `b` in overriding signature.";
    ];
  assert_type_errors
    ~debug:false
    {|
      class Foo():
        def f(self, c: str) -> None: ...
      class Bar(Foo):
        def f(self, *args: typing.Any, **kwargs: typing.Any) -> None: pass
    |}
    []


let test_check_nested_class_inheritance _ =
  assert_type_errors
    {|
      class X():
          class Q():
              pass

      class Y(X):
          pass

      def foo() -> Y.Q:
          return Y.Q()
    |}
    [];
  assert_type_errors
    {|
      class X():
          class Q():
              pass

      class Y(X):
          pass

      def foo() -> Y.Q:
          return X.Q()
    |}
    [];
  assert_type_errors
    {|
      class X():
          class Q():
              pass

      class Y(X):
          pass

      class Z():
          class Q():
              pass

      def foo() -> Y.Q:
          return Z.Q()
    |}
    ["Incompatible return type [7]: Expected `X.Q` but got `Z.Q`."];
  assert_type_errors
    {|
      class X:
        class N:
          class NN:
            class NNN:
              pass
      class Y(X):
        pass
      def foo() -> Y.N.NN.NNN:
          return Y.N.NN.NNN()
    |}
    [];
  assert_type_errors
    {|
      class B1:
        class N:
          pass
      class B2:
        class N:
          pass
      class C(B1, B2):
        pass
      def foo() -> C.N:
        return C.N()
    |}
    []


let test_check_method_resolution _ =
  assert_type_errors
    {|
      def foo() -> None:
        bar().baz()
    |}
    ["Undefined name [18]: Global name `bar` is undefined."];

  assert_type_errors
    {|
      def foo(input: str) -> None:
        input.lower()
    |}
    []


let test_check_callable_protocols _ =
  (* Objects with a `__call__` method are callables. *)
  assert_type_errors
    {|
      class Call:
        def __call__(self) -> int: ...
      def foo(call: Call) -> int:
        return call()
    |}
    [];

  (* We handle subclassing. *)
  assert_type_errors
    {|
      class BaseClass:
        def __call__(self, val: typing.Optional[str] = None) -> "BaseClass":
          ...
      class SubClass(BaseClass):
        pass
      def f(sc: SubClass) -> None:
        sc('foo')
    |}
    [];

  assert_type_errors
    {|
      class Call:
        def not_call(self) -> int: ...
      def foo(call: Call) -> int:
        return call()
    |}
    [
      "Incompatible return type [7]: Expected `int` but got `unknown`.";
      "Call error [29]: `Call` is not a function.";
    ];

  assert_type_errors
    ~debug:false
    {|
      def foo(call) -> int:
        return call()
    |}
    [];

  (* Test for terminating fixpoint *)
  assert_type_errors
    {|
      class Call:
        def not_call(self) -> int: ...
      def foo(x: int, call: Call) -> int:
        for x in range(0, 7):
          call()
        return 7
    |}
    [
      "Call error [29]: `Call` is not a function.";
    ];

  assert_type_errors
    {|
      class patch:
        def __call__(self) -> int: ...

      unittest.mock.patch: patch = ...

      def foo() -> None:
        unittest.mock.patch()
        unittest.mock.patch()  # subequent calls should not modify annotation map
    |}
    [];

  assert_type_errors
    {|
      class Foo:
        def bar(self, x: int) -> str:
          return ""

      def bar() -> None:
        return Foo.bar
    |}
    [
      "Incompatible return type [7]: Expected `None` but got " ^
      "`typing.Callable(Foo.bar)[[Named(self, unknown), Named(x, int)], str]`.";
    ];

  assert_type_errors
    {|
      class Foo:
        @classmethod
        def bar(self, x: int) -> str:
          return ""

      def bar() -> None:
        return Foo.bar
    |}
    [
      "Incompatible return type [7]: Expected `None` but got " ^
      "`typing.Callable(Foo.bar)[[Named(x, int)], str]`.";
    ];

  assert_type_errors
    {|
      class Call:
        def __call__(self, x: int) -> int: ...
      def foo(call: Call) -> int:
        return call("")
    |}
    [
      "Incompatible parameter type [6]: Expected `int` for 1st anonymous parameter to call \
       `Call.__call__` but got `str`.";
    ]


let test_check_explicit_method_call _ =
  assert_type_errors
    {|
      class Class:
        def method(self, i: int) -> None:
          pass
      Class.method(object(), 1)
    |}
    []


let test_check_self _ =
  (* Self parameter is typed. *)
  assert_type_errors
    {|
      class Foo:
        def foo(self) -> int:
          return 1
        def bar(self) -> str:
          return self.foo()
    |}
    ["Incompatible return type [7]: Expected `str` but got `int`."];

  assert_type_errors
    {|
      class Other:
          pass

      class Some:
          def one(self) -> None:
              self.two()

          def two(self: Other) -> None:
              pass
    |}
    [
      "Incompatible variable type [9]: self is declared to have type `Other` but is used as type \
       `Some`.";
    ];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class C:
        def f(self: T, x: int) -> T:
          return self
      class Subclass(C):
        pass
      def f() -> C:
        a = Subclass()
        b = a.f
        return b(1)
      def f() -> Subclass:
        a = Subclass()
        b = a.f
        return b(1)
    |}
    [];

  (* Make sure the SelfType pattern works *)
  assert_type_errors
    {|
      TSelf = typing.TypeVar('TSelf', bound="C")
      class C:
        def inner(self, x: int) -> None:
          pass
        def verbose(self: TSelf, x: int) -> TSelf:
          self.inner(x)
          return self
      SubTSelf = typing.TypeVar('SubTSelf', bound="Subclass")
      class Subclass(C):
        def subinner(self, x:str) -> None:
          pass
        def interface(self: SubTSelf, x: str) -> SubTSelf:
          self.inner(7)
          self.subinner(x)
          return self
      class SubSubclass(Subclass): pass
      def f() -> SubSubclass:
        return SubSubclass().verbose(7).interface("A")
      def g() -> SubSubclass:
        return SubSubclass().interface("A").verbose(7)
    |}
    []


let test_check_meta_self _ =
  assert_type_errors
    ~debug:false
    {|
      T = typing.TypeVar('T')
      S = typing.TypeVar('S')
      class C(typing.Generic[T]): pass
      def foo(input: typing.Any) -> None:
        typing.cast(C[int], input)
      class D(typing.Generic[T, S]): pass
      def foo(input: typing.Any) -> None:
        typing.cast(D[int, float], input)
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class C:
        @classmethod
        def __construct__(cls: typing.Type[T]) -> T:
          ...
      class Subclass(C):
        ...
      def foo()-> C:
        return C.__construct__()
      def boo() -> Subclass:
        return Subclass.__construct__()
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class C:
        @classmethod
        def __construct__(cls: typing.Type[T]) -> T:
          ...
      class Subclass(C):
        ...
      def foo() -> C:
        return Subclass.__construct__()
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class C:
        @classmethod
        def __construct__(cls: typing.Type[T]) -> T:
          ...
      class Subclass(C):
        ...
      def foo()-> Subclass:
        return C.__construct__()
    |}
    ["Incompatible return type [7]: Expected `Subclass` but got `C`."];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class C:
        def f(self: T) -> T:
          ...
      class Subclass(C):
        ...
      def foo(s: Subclass) -> Subclass:
        to_call = s.f
        return to_call()
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      class C:
        def f(self: T) -> T:
          ...
      class Subclass(C):
        ...
      def foo(c: C)-> Subclass:
        to_call = c.f
        return to_call()
    |}
    ["Incompatible return type [7]: Expected `Subclass` but got `C`."];


  assert_type_errors
    {|
      class Foo:
        def foo(self) -> typing.Type[Foo]:
          return type(self)
        def bar(self) -> typing.Type[int]:
          return type(1)
    |}
    [];
  assert_type_errors
    {|
      class Foo:
        ATTRIBUTE: typing.ClassVar[int] = 1
        def foo(self) -> int:
          return type(self).ATTRIBUTE
    |}
    [];
  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def foo(t: T) -> str:
        return type(t).__name__
    |}
    [];

  assert_type_errors
    {|
      def foo(x: int) -> str:
        return type(x).__name__
    |}
    [];

  assert_type_errors
    {|
      class C:
        pass
      R = C
      def foo() -> C:
        return R()
    |}
    []


let test_check_static _ =
  (* No self parameter in static method. *)
  assert_type_errors
    {|
      class Foo:
        @staticmethod
        def bar(input: str) -> str:
          return input.lower()

      class Bar:
        @classmethod
        def bar(cls, input: str) -> str:
          return input.lower()

        def baz(self) -> None:
          self.bar("")
    |}
    [];

  (* Static method calls are properly resolved. *)
  assert_type_errors
    {|
      class Foo:
        @staticmethod
        def foo(input: int) -> int:
          return input

      def foo() -> None:
        Foo.foo('asdf')
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `Foo.foo` but got `str`."];

  assert_type_errors
    {|
      class Foo:
        @staticmethod
        def foo(input: int) -> int:
          return input

        def bar(self) -> None:
          self.foo('asdf')

    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `Foo.foo` but got `str`."];

  (* Class method calls are properly resolved. *)
  assert_type_errors
    {|
      class Foo:
        @classmethod
        def foo(cls, input: int) -> int:
          return input

      def foo() -> None:
        Foo.foo('asdf')
    |}
    [
      "Incompatible parameter type [6]: Expected `int` for 1st anonymous parameter to call \
       `Foo.foo` but got `str`.";
    ];

  assert_type_errors
    {|
      class Foo:
        @classmethod
        def foo(cls) -> typing.Type[Foo]:
          return cls
    |}
    [];

  assert_type_errors
    {|
      class Foo:
        @classmethod
        def classmethod(cls, i: int) -> None:
          cls.classmethod('1234')
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `Foo.classmethod` but got `str`."];

  assert_type_errors
    {|
      class Foo:
        @staticmethod
        def staticmethod(i: int) -> None:
          pass
        @classmethod
        def classmethod(cls, i: int) -> None:
          cls.staticmethod('1234')
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `Foo.staticmethod` but got `str`."];

  assert_type_errors
    {|
      class Foo:
        def instancemethod(self, i: int) -> None:
          pass
        @classmethod
        def classmethod(cls, i: int) -> None:
          cls.instancemethod(Foo(), '1234')
    |}
    [
      "Incompatible parameter type [6]: Expected `int` for 2nd anonymous parameter to call \
       `Foo.instancemethod` but got `str`.";
    ];

  (* Special classmethods are treated properly without a decorator. *)
  assert_type_errors
    {|
      class Foo:
        def __init_subclass__(cls) -> typing.Type[Foo]:
          return cls
        def __new__(cls) -> typing.Type[Foo]:
          return cls
        def __class_getitem__(cls, key: int) -> typing.Type[Foo]:
          return cls
    |}
    []


let test_check_setitem _ =
  assert_type_errors
    {|
      def foo(x: typing.Dict[str, int]) -> None:
        x["foo"] = "bar"
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 2nd anonymous parameter to call `dict.__setitem__` but got `str`."];

  assert_type_errors
    {|
      class A:
        pass
      def foo(x: typing.Dict[str, int], y: A) -> None:
        x["foo"] = y["bar"] = "baz"
    |}
    [
      "Undefined attribute [16]: `A` has no attribute `__setitem__`.";
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 2nd anonymous parameter to call `dict.__setitem__` but got `str`.";
    ];

  assert_type_errors
    {|
      def foo(x: typing.Dict[str, typing.Dict[str, int]]) -> None:
        x["foo"]["bar"] = "baz"
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 2nd anonymous parameter to call `dict.__setitem__` but got `str`."];

  assert_type_errors
    {|
      def foo(x: typing.Dict[str, int]) -> None:
        x[7] = 7
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `str` for 1st anonymous parameter to call `dict.__setitem__` but got `int`."]


let test_check_in _ =
  assert_type_errors
    {|
      class WeirdContains:
        def __contains__(self, x: int) -> int:
          ...
      reveal_type(1 in WeirdContains())
    |}
    ["Revealed type [-1]: Revealed type for `1 in WeirdContains()` is `int`."];

  assert_type_errors
    {|
      class WeirdIterator:
        def __eq__(self, other) -> str:
          ...
        def __iter__(self) -> typing.Iterator[WeirdIterator]:
          ...
      reveal_type(1 in WeirdIterator())
    |}
    ["Revealed type [-1]: Revealed type for `1 in WeirdIterator()` is `str`."];
  assert_type_errors
    {|
      class WeirdEqual:
        def __eq__(self, other: object) -> typing.List[int]:
          ...
      class WeirdGetItem:
        def __getitem__(self, x: int) -> WeirdEqual:
          ...
      reveal_type(1 in WeirdGetItem())
    |}
    ["Revealed type [-1]: Revealed type for `1 in WeirdGetItem()` is `typing.List[int]`."];
  assert_type_errors
    {|
      class Equal:
        def __eq__(self, other: object) -> str:
          ...
      class Multiple:
        def __iter__(self, x: int) -> typing.Iterator[Equal]:
          ...
        def __contains__(self, a: object) -> bool:
          ...
      reveal_type(1 in Multiple())
    |}
    ["Revealed type [-1]: Revealed type for `1 in Multiple()` is `bool`."];
  assert_type_errors
    {|
      class Equal:
        def __eq__(self, other: object) -> str:
          ...
      class Multiple:
        def __getitem__(self, x: int) -> Equal:
          ...
        def __contains__(self, a: object) -> int:
          ...
      reveal_type(1 in Multiple())
    |}
    ["Revealed type [-1]: Revealed type for `1 in Multiple()` is `int`."];
  assert_type_errors
    {|
      class Equal:
        def __eq__(self, other: object) -> typing.List[int]:
          ...
      class GetItemA:
        def __getitem__(self, x: int) -> Equal:
          ...
      class GetItemB:
        def __getitem__(self, x: int) -> Equal:
          ...
      def foo(a: typing.Union[GetItemA, GetItemB]) -> None:
        5 in a
    |}
    []


let test_check_enter _ =
  assert_type_errors
    {|
      class WithClass():
        def __enter__(self) -> str:
          return ''

      def expect_string(x: str) -> None:
        pass

      def test() -> None:
        with WithClass() as x:
          expect_string(x)
    |}
    [];

  assert_type_errors
    {|
      class WithClass():
        def __enter__(self) -> int:
          return 5

      def expect_string(x: str) -> None:
        pass

      def test() -> None:
        with WithClass() as x:
          expect_string(x)

    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `str` for 1st anonymous parameter to call `expect_string` but got `int`."]


let () =
  "method">:::[
    "check_method_returns">::test_check_method_returns;
    "check_method_parameters">::test_check_method_parameters;
    "check_abstract_methods">::test_check_abstract_methods;
    "check_behavioral_subtyping">::test_check_behavioral_subtyping;
    "check_nested_class_inheritance">::test_check_nested_class_inheritance;
    "check_method_resolution">::test_check_method_resolution;
    "check_callable_protocols">::test_check_callable_protocols;
    "check_explicit_method_call">::test_check_explicit_method_call;
    "check_self">::test_check_self;
    "check_meta_self">::test_check_meta_self;
    "check_setitem">::test_check_setitem;
    "check_static">::test_check_static;
    "check_in">::test_check_in;
    "check_enter">::test_check_enter;
  ]
  |> Test.run
