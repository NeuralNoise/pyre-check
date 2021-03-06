(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open Core
open OUnit2

open Ast
open Analysis
open Pyre
open Statement
open Test


let define_value ?(return_annotation = Some !"int") ?(body = []) ?(name = "foo") () =
  {
    Statement.Define.name = Access.create name;
    parameters = [];
    body;
    decorators = [];
    docstring = None;
    return_annotation;
    async = false;
    parent = None;
  }


let untyped_define =
  +(define_value ~return_annotation:None ~body:[] ())


let define ?(body = []) () =
  +(define_value ~body ())


let mock_define =
  define ()


let mock_parent = Type.Primitive "foo"


let error ?(define = mock_define) ?(location = Location.Instantiated.any) kind =
  { Error.location; kind; define }


let revealed_type access annotation =
  Error.RevealedType {
    expression = Access.expression (Access.create access);
    annotation;
  }


let missing_return annotation =
  Error.MissingReturnAnnotation {
    name = Access.create "$return_annotation";
    annotation = Some annotation;
    evidence_locations = [];
    given_annotation = None;
  }


let incompatible_return_type ?(due_to_invariance = false) actual expected =
  Error.IncompatibleReturnType {
    mismatch = { Error.actual; expected; due_to_invariance };
    is_implicit = false;
  }


let undefined_attribute actual =
  Error.UndefinedAttribute {
    attribute = Access.create "foo";
    origin = Error.Class {
        annotation = actual;
        class_attribute = false;
      };
  }

let unexpected_keyword name callee =
  Error.UnexpectedKeyword {
    name = name;
    callee = callee >>| Access.create;
  }


let configuration = Configuration.Analysis.create ()


let test_due_to_analysis_limitations _ =
  let assert_due_to_analysis_limitaitons kind =
    assert_true (Error.due_to_analysis_limitations (error kind))
  in
  let assert_not_due_to_analysis_limitations kind =
    assert_false (Error.due_to_analysis_limitations (error kind))
  in

  (* IncompatibleAttributeType. *)
  assert_due_to_analysis_limitaitons
    (Error.IncompatibleAttributeType {
        parent = mock_parent;
        incompatible_type = {
          Error.name = [Access.Identifier ""];
          mismatch = {
            Error.actual = Type.Top;
            expected = Type.Top;
            due_to_invariance = false;
          };
          declare_location = Location.Instantiated.any;
        };
      });
  assert_due_to_analysis_limitaitons
    (Error.IncompatibleAttributeType {
        parent = mock_parent;
        incompatible_type = {
          Error.name = [Access.Identifier ""];
          mismatch = {
            Error.actual = Type.Top;
            expected = Type.string;
            due_to_invariance = false;
          };
          declare_location = Location.Instantiated.any;
        };
      });
  assert_not_due_to_analysis_limitations
    (Error.IncompatibleAttributeType {
        parent = mock_parent;
        incompatible_type = {
          Error.name = [Access.Identifier ""];
          mismatch = {
            Error.actual = Type.string;
            expected = Type.Top;
            due_to_invariance = false;
          };
          declare_location = Location.Instantiated.any;
        };
      });

  (* Initialization *)
  assert_due_to_analysis_limitaitons
    (Error.UninitializedAttribute {
        name = [Access.Identifier ""];
        parent = mock_parent;
        mismatch = {
          Error.actual = Type.Top;
          expected = Type.Optional Type.Top;
          due_to_invariance = false;
        };
      });

  assert_not_due_to_analysis_limitations
    (Error.UninitializedAttribute {
        name = [Access.Identifier ""];
        parent = mock_parent;
        mismatch = {
          Error.actual = Type.string;
          expected = Type.Optional Type.string;
          due_to_invariance = false;
        };
      });

  (* MissingParameterAnnotation. *)
  assert_due_to_analysis_limitaitons
    (Error.MissingParameterAnnotation {
        name = (Access.create "");
        annotation = Some Type.Top;
        evidence_locations = [];
        given_annotation = None;
      });
  assert_not_due_to_analysis_limitations
    (Error.MissingParameterAnnotation {
        name = (Access.create "");
        annotation = Some Type.string;
        evidence_locations = [];
        given_annotation = None;
      });

  (* MissingReturnAnnotation. *)
  assert_due_to_analysis_limitaitons
    (Error.MissingReturnAnnotation {
        name = (Access.create "$return_annotation");
        annotation = Some Type.Top;
        evidence_locations = [];
        given_annotation = None;
      });
  assert_not_due_to_analysis_limitations
    (Error.MissingReturnAnnotation {
        name = (Access.create "$return_annotation");
        annotation = Some Type.string;
        evidence_locations = [];
        given_annotation = None;
      });

  (* MissingAttributeAnnotation *)
  assert_due_to_analysis_limitaitons
    (Error.MissingAttributeAnnotation {
        parent = mock_parent;
        missing_annotation = {
          Error.name = [Access.Identifier ""];
          annotation = Some Type.Top;
          given_annotation = None;
          evidence_locations = [];
        };
      });
  assert_not_due_to_analysis_limitations
    (Error.MissingAttributeAnnotation {
        parent = mock_parent;
        missing_annotation = {
          Error.name = [Access.Identifier ""];
          annotation = Some Type.string;
          given_annotation = None;
          evidence_locations = [];
        };
      });
  assert_not_due_to_analysis_limitations
    (Error.MissingAttributeAnnotation {
        parent = mock_parent;
        missing_annotation = {
          Error.name = [Access.Identifier ""];
          annotation = None;
          given_annotation = None;
          evidence_locations = [];
        };
      });

  (* Parameter. *)
  assert_due_to_analysis_limitaitons
    (Error.IncompatibleParameterType {
        name = Some ((Access.create ""));
        position = 1;
        callee = Some (Access.create "callee");
        mismatch = {
          Error.actual = Type.Top;
          expected = Type.Top;
          due_to_invariance = false;
        };
      });
  assert_due_to_analysis_limitaitons
    (Error.IncompatibleParameterType {
        name = Some ((Access.create ""));
        position = 1;
        callee = Some (Access.create "callee");
        mismatch = {
          Error.actual = Type.Top;
          expected = Type.string;
          due_to_invariance = false;
        };
      });
  assert_not_due_to_analysis_limitations
    (Error.IncompatibleParameterType {
        name = Some ((Access.create ""));
        position = 1;
        callee = Some (Access.create "callee");
        mismatch = {
          Error.actual = Type.string;
          expected = Type.Top;
          due_to_invariance = false;
        };
      });

  assert_due_to_analysis_limitaitons
    (Error.IncompatibleParameterType {
        name = Some ((Access.create ""));
        position = 1;
        callee = Some (Access.create "callee");
        mismatch = {
          Error.actual = Type.Primitive "typing.TypeAlias";
          expected = Type.Top;
          due_to_invariance = false;
        };
      });

  (* Return. *)
  assert_due_to_analysis_limitaitons
    (Error.IncompatibleReturnType {
        mismatch = {
          Error.actual = Type.Top;
          expected = Type.Top;
          due_to_invariance = false;
        };
        is_implicit = false;
      });
  assert_due_to_analysis_limitaitons
    (Error.IncompatibleReturnType {
        mismatch = {
          Error.actual = Type.Top;
          expected = Type.string;
          due_to_invariance = false;
        };
        is_implicit = false;
      });
  assert_not_due_to_analysis_limitations
    (Error.IncompatibleReturnType {
        mismatch = {
          Error.actual = Type.string;
          expected = Type.Top;
          due_to_invariance = false;
        };
        is_implicit = false;
      });

  (* UndefinedType. *)
  assert_not_due_to_analysis_limitations (Error.UndefinedType Type.Top);
  assert_not_due_to_analysis_limitations (Error.UndefinedType Type.string);

  (* Unpack. *)
  assert_not_due_to_analysis_limitations
    (Error.Unpack { expected_count = 2; unpack_problem = CountMismatch 3 });
  assert_not_due_to_analysis_limitations
    (Error.Unpack { expected_count = 2; unpack_problem = UnacceptableType Type.integer });
  assert_due_to_analysis_limitaitons
    (Error.Unpack { expected_count = 2; unpack_problem = UnacceptableType Type.Top })


let test_due_to_mismatch_with_any _ =
  let assert_due_to_mismatch_with_any kind =
    assert_true (Error.due_to_mismatch_with_any (error kind))
  in
  let assert_not_due_to_mismatch_with_any kind =
    assert_false (Error.due_to_mismatch_with_any (error kind))
  in
  (* ImpossibleIsinstance *)
  assert_due_to_mismatch_with_any
    (Error.ImpossibleIsinstance {
        expression = !"expression";
        mismatch = {
          Error.actual = Type.Object;
          expected = Type.Object;
          due_to_invariance = false;
        };
      });

  (* IncompatibleAttributeType. *)
  assert_due_to_mismatch_with_any
    (Error.IncompatibleAttributeType {
        parent = mock_parent;
        incompatible_type = {
          Error.name = [Access.Identifier ""];
          mismatch = {
            Error.actual = Type.Object;
            expected = Type.Object;
            due_to_invariance = false;
          };
          declare_location = Location.Instantiated.any;
        };
      });

  (* IncompatibleAwaitableType *)
  assert_due_to_mismatch_with_any (Error.IncompatibleAwaitableType Type.Object);

  (* IncompatibleParameterType *)
  assert_due_to_mismatch_with_any
    (Error.IncompatibleParameterType {
        name = Some ((Access.create ""));
        position = 1;
        callee = Some (Access.create "callee");
        mismatch = {
          Error.actual = Type.Object;
          expected = Type.Object;
          due_to_invariance = false;
        };
      });
  assert_due_to_mismatch_with_any
    (Error.IncompatibleParameterType {
        name = Some ((Access.create ""));
        position = 1;
        callee = Some (Access.create "callee");
        mismatch = {
          Error.actual = Type.string;
          expected = Type.Object;
          due_to_invariance = false;
        };
      });

  (* IncompatibleReturnType *)
  assert_due_to_mismatch_with_any
    (Error.IncompatibleReturnType {
        mismatch = {
          Error.actual = Type.Object;
          expected = Type.Object;
          due_to_invariance = false;
        };
        is_implicit = false;
      });
  assert_due_to_mismatch_with_any
    (Error.IncompatibleReturnType {
        mismatch = {
          Error.actual = Type.Object;
          expected = Type.string;
          due_to_invariance = false;
        };
        is_implicit = false;
      });
  assert_not_due_to_mismatch_with_any
    (Error.IncompatibleReturnType {
        mismatch = {
          Error.actual = Type.string;
          expected = Type.integer;
          due_to_invariance = false;
        };
        is_implicit = false;
      });

  (* IncompatibleVariableType *)
  assert_due_to_mismatch_with_any
    (Error.IncompatibleVariableType {
        name = [Expression.Access.Identifier "name"];
        mismatch = {
          Error.actual = Type.string;
          expected = Type.Object;
          due_to_invariance = false;
        };
        declare_location = Location.Instantiated.any;
      });

  (* InconsistentOverride *)
  assert_not_due_to_mismatch_with_any
    (InconsistentOverride {
        overridden_method = Access.create "foo";
        parent = Access.create (Type.show mock_parent);
        override = (StrengthenedPrecondition (NotFound (Access.create "x")));
      });
  assert_not_due_to_mismatch_with_any
    (InconsistentOverride {
        overridden_method = Access.create "foo";
        parent = Access.create (Type.show mock_parent);
        override = (WeakenedPostcondition {
            actual = Type.Top;
            expected = Type.integer;
            due_to_invariance = false;
          });
      });
  assert_due_to_mismatch_with_any
    (InconsistentOverride {
        overridden_method = Access.create "foo";
        parent = Access.create (Type.show mock_parent);
        override = (WeakenedPostcondition {
            actual = Type.Object;
            expected = Type.integer;
            due_to_invariance = false;
          });
      });
  assert_not_due_to_mismatch_with_any
    (InconsistentOverride {
        overridden_method = Access.create "foo";
        parent = Access.create (Type.show mock_parent);
        override = (StrengthenedPrecondition (Found {
            actual = Type.none;
            expected = Type.integer;
            due_to_invariance = false;
          }));
      });
  assert_due_to_mismatch_with_any
    (InconsistentOverride {
        overridden_method = Access.create "foo";
        parent = Access.create (Type.show mock_parent);
        override = (StrengthenedPrecondition (Found {
            actual = Type.none;
            expected = Type.Object;
            due_to_invariance = false;
          }));
      });

  (* InvalidArgument *)
  assert_not_due_to_mismatch_with_any
    (InvalidArgument (
        Keyword {
          expression = !"name";
          annotation = Type.integer;
        }
      ));
  assert_not_due_to_mismatch_with_any
    (InvalidArgument (
        Variable {
          expression = !"name";
          annotation = Type.integer;
        }
      ));
  assert_due_to_mismatch_with_any
    (InvalidArgument (
        Keyword {
          expression = !"name";
          annotation = Type.Object;
        }
      ));
  assert_due_to_mismatch_with_any
    (InvalidArgument (
        Variable {
          expression = !"name";
          annotation = Type.Object;
        }
      ));

  (* NotCallable *)
  assert_due_to_mismatch_with_any (Error.NotCallable Type.Object);
  assert_not_due_to_mismatch_with_any (Error.NotCallable Type.Top);

  (* UndefinedAttribute *)
  assert_due_to_mismatch_with_any
    (Error.UndefinedAttribute {
        attribute = Access.create "foo";
        origin = Error.Class {
            annotation = Type.Object;
            class_attribute = false;
          };
      });

  assert_not_due_to_mismatch_with_any
    (Error.UndefinedAttribute {
        attribute = Access.create "foo";
        origin = Error.Module (Access.create "module");
      });

  (* Uninitialized Attribute *)
  assert_due_to_mismatch_with_any
    (Error.UninitializedAttribute {
        name = [Access.Identifier ""];
        parent = mock_parent;
        mismatch = {
          Error.actual = Type.Object;
          expected = Type.Optional Type.integer;
          due_to_invariance = false;
        };
      });

  assert_not_due_to_mismatch_with_any
    (Error.UninitializedAttribute {
        name = [Access.Identifier ""];
        parent = mock_parent;
        mismatch = {
          Error.actual = Type.string;
          expected = Type.Optional Type.string;
          due_to_invariance = false;
        };
      });

  (* Unpack *)
  assert_not_due_to_mismatch_with_any
    (Error.Unpack { expected_count = 2; unpack_problem = CountMismatch 3 });
  assert_not_due_to_mismatch_with_any
    (Error.Unpack { expected_count = 2; unpack_problem = UnacceptableType Type.integer });
  assert_due_to_mismatch_with_any
    (Error.Unpack { expected_count = 2; unpack_problem = UnacceptableType Type.Object });

  (* Missing X errors *)
  assert_not_due_to_mismatch_with_any
    (Error.MissingParameterAnnotation {
        name = (Access.create "");
        annotation = Some Type.Object;
        evidence_locations = [];
        given_annotation = None;
      });

  assert_not_due_to_mismatch_with_any
    (Error.MissingReturnAnnotation {
        name = (Access.create "$return_annotation");
        annotation = Some Type.Top;
        evidence_locations = [];
        given_annotation = None;
      });

  assert_not_due_to_mismatch_with_any
    (Error.MissingAttributeAnnotation {
        parent = mock_parent;
        missing_annotation = {
          Error.name = [Access.Identifier ""];
          annotation = Some Type.Object;
          given_annotation = None;
          evidence_locations = [];
        };
      })


let test_join _ =
  let assert_join left right expected =
    let environment =
      Environment.handler ~configuration (Environment.Builder.create ())
    in
    let resolution = TypeCheck.resolution environment () in
    let result = Error.join ~resolution left right in
    assert_equal ~printer:Error.show ~cmp:Error.equal result expected
  in
  assert_join
    (error
       (Error.IncompatibleAttributeType {
           parent = mock_parent;
           incompatible_type = {
             Error.name = [Access.Identifier ""];
             mismatch = {
               Error.actual = Type.Top;
               expected = Type.Top;
               due_to_invariance = false;
             };
             declare_location = Location.Instantiated.any;
           };
         }))
    (error (Error.IncompatibleVariableType {
         Error.name = [Access.Identifier ""];
         mismatch = {
           Error.actual = Type.Top;
           expected = Type.Top;
           due_to_invariance = false;
         };
         declare_location = Location.Instantiated.any;
       }))
    (error Error.Top);
  assert_join
    (error
       (Error.IncompatibleParameterType {
           name = Some (Access.create "");
           position = 1;
           callee = Some (Access.create "callee");
           mismatch = {
             Error.actual = Type.integer;
             expected = Type.string;
             due_to_invariance = false;
           };
         }))
    (error
       (Error.IncompatibleParameterType {
           name = Some (Access.create "");
           position = 1;
           callee = Some (Access.create "callee");
           mismatch = {
             Error.actual = Type.float;
             expected = Type.string;
             due_to_invariance = false;
           };
         }))
    (error
       (Error.IncompatibleParameterType {
           name = Some (Access.create "");
           position = 1;
           callee = Some (Access.create "callee");
           mismatch = {
             Error.actual = Type.float;
             expected = Type.string;
             due_to_invariance = false;
           };
         }));
  let create_mock_location path =
    {
      Location.path;
      start = { Location.line = 1; column = 1 };
      stop = { Location.line = 1; column = 1 };
    }
  in
  assert_join
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.integer;
           evidence_locations = [create_mock_location "derp.py"];
           given_annotation = None;
         }))
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.float;
           evidence_locations = [create_mock_location "durp.py"];
           given_annotation = None;
         }))
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.float;
           evidence_locations = [create_mock_location "derp.py"; create_mock_location "durp.py"];
           given_annotation = None;
         }));
  assert_join
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.integer;
           evidence_locations = [create_mock_location "derp.py"];
           given_annotation = None;
         }))
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = None;
           evidence_locations = [];
           given_annotation = None;
         }))
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.integer;
           evidence_locations = [create_mock_location "derp.py"];
           given_annotation = None;
         }));
  assert_join
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = None;
           evidence_locations = [];
           given_annotation = None;
         }))
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.float;
           evidence_locations = [create_mock_location "durp.py"];
           given_annotation = None;
         }))
    (error
       (Error.MissingGlobalAnnotation {
           Error.name = [Access.Identifier ""];
           annotation = Some Type.float;
           evidence_locations = [create_mock_location "durp.py"];
           given_annotation = None;
         }));

  assert_join
    (error (Error.UndefinedType (Type.Primitive "derp")))
    (error (Error.UndefinedType (Type.Primitive "derp")))
    (error (Error.UndefinedType (Type.Primitive "derp")));

  assert_join
    (error (Error.UndefinedType (Type.Primitive "derp")))
    (error (Error.UndefinedType (Type.Primitive "herp")))
    (error (Error.Top));

  assert_join
    (error (Error.AnalysisFailure (Type.Primitive "derp")))
    (error (Error.AnalysisFailure (Type.Primitive "derp")))
    (error (Error.AnalysisFailure (Type.Primitive "derp")));

  assert_join
    (error (Error.AnalysisFailure (Type.Primitive "derp")))
    (error (Error.AnalysisFailure (Type.Primitive "herp")))
    (error (Error.AnalysisFailure (Type.union [Type.Primitive "derp"; Type.Primitive "herp"])));

  assert_join
    (error (revealed_type "a" Type.integer))
    (error (revealed_type "a" Type.float))
    (error (revealed_type "a" Type.float));
  assert_join
    (error (revealed_type "a" Type.integer))
    (error (revealed_type "b" Type.float))
    (error (Error.Top))


let test_filter _ =
  let open Error in
  let environment =
    Environment.handler ~configuration (Environment.Builder.create ())
  in
  add_defaults_to_environment ~configuration environment;
  Service.Environment.populate
    ~configuration
    environment
    [
      parse {|
        class Foo: ...
        class MockChild(unittest.mock.Mock): ...
        class NonCallableChild(unittest.mock.NonCallableMock): ...
        class NonMockChild(Foo): ...
      |};
    ];
  let resolution = TypeCheck.resolution environment () in
  let assert_filtered ?(location = Location.Instantiated.any) ?(define = mock_define) kind =
    let errors = [error ~define ~location kind] in
    assert_equal
      []
      (filter ~configuration ~resolution errors)
  in
  let assert_unfiltered ?(location = Location.Instantiated.any) ?(define = mock_define) kind =
    let errors = [error ~define ~location kind] in
    assert_equal
      ~cmp:(List.equal ~equal)
      errors
      (filter ~configuration ~resolution errors)
  in
  (* Suppress stub errors. *)
  let stub = { Location.Instantiated.any with Location.path = "stub.pyi" } in
  assert_filtered ~location:stub (undefined_attribute (Type.Primitive "Foo"));
  assert_unfiltered
    ~location:Location.Instantiated.any
    (undefined_attribute (Type.Primitive "Foo"));

  (* Suppress mock errors. *)
  assert_filtered (incompatible_return_type (Type.Primitive "unittest.mock.Mock") Type.integer);
  assert_unfiltered (incompatible_return_type Type.integer (Type.Primitive "unittest.mock.Mock"));
  assert_filtered (undefined_attribute (Type.Primitive "MockChild"));
  assert_filtered (undefined_attribute (Type.Primitive "NonCallableChild"));
  assert_unfiltered (undefined_attribute (Type.Primitive "NonMockChild"));
  assert_filtered (undefined_attribute (Type.Optional (Type.Primitive "NonCallableChild")));
  assert_unfiltered (incompatible_return_type (Type.Optional Type.Bottom) Type.integer);
  assert_filtered (unexpected_keyword "foo" (Some "unittest.mock.call"));
  assert_unfiltered (unexpected_keyword "foo" None);

  (* Suppress return errors in unimplemented defines. *)
  assert_unfiltered (incompatible_return_type Type.integer Type.float);
  assert_filtered
    ~define:(define ~body:[+Statement.Pass;
                           +Statement.Return { Return.expression = None; is_implicit = false }] ())
    (incompatible_return_type Type.integer Type.float);

  (* Suppress errors due to importing builtins. *)
  let undefined_import import = UndefinedImport (Access.create import) in
  assert_filtered (undefined_import "builtins");
  assert_unfiltered (undefined_import "sys");

  let inconsistent_override name override =
    InconsistentOverride {
      overridden_method = Access.create name;
      parent = Access.create (Type.show mock_parent);
      override;
    }
  in
  (* Suppress parameter errors on override of dunder methods *)
  assert_unfiltered
    (inconsistent_override
       "foo"
       (StrengthenedPrecondition (NotFound (Access.create "x"))));
  assert_unfiltered
    (inconsistent_override
       "__foo__"
       (WeakenedPostcondition {
           actual = Type.Top;
           expected = Type.integer;
           due_to_invariance = false;
         }));
  assert_unfiltered
    (inconsistent_override
       "__foo__"
       (StrengthenedPrecondition (Found {
            actual = Type.none;
            expected = Type.integer;
            due_to_invariance = false;
          })));
  assert_filtered
    (inconsistent_override
       "__foo__"
       (StrengthenedPrecondition (NotFound (Access.create "x"))))


let test_suppress _ =
  let assert_suppressed mode ?(define = mock_define) ?location kind =
    assert_equal
      true
      (Error.suppress ~mode (error ~define ?location kind))
  in
  let assert_not_suppressed mode ?(define = mock_define) kind =
    assert_equal
      false
      (Error.suppress ~mode (error ~define kind))
  in

  (* Test different modes. *)
  assert_suppressed Source.Infer (missing_return Type.Top);
  assert_suppressed Source.Infer (missing_return Type.Object);
  assert_not_suppressed Source.Infer (missing_return Type.integer);
  assert_suppressed Source.Infer (Error.UndefinedType Type.integer);
  assert_suppressed Source.Infer (Error.AnalysisFailure Type.integer);

  assert_not_suppressed Source.Strict (missing_return Type.Top);
  assert_suppressed Source.Strict (Error.IncompatibleAwaitableType Type.Top);
  assert_not_suppressed Source.Strict (missing_return Type.Object);
  assert_not_suppressed Source.Strict (Error.AnalysisFailure Type.integer);

  assert_suppressed Source.Default (missing_return Type.integer);
  assert_not_suppressed Source.Default (incompatible_return_type Type.integer Type.float);
  assert_suppressed Source.Default (incompatible_return_type Type.integer Type.Object);
  assert_not_suppressed Source.Default (revealed_type "a" Type.integer);
  assert_not_suppressed ~define:untyped_define Source.Default (revealed_type "a" Type.integer);
  assert_suppressed Source.Default (Error.UndefinedName (Access.create "reveal_type"));
  assert_not_suppressed Source.Default (Error.AnalysisFailure Type.integer);

  assert_suppressed
    Source.Default
    (Error.MissingTypeParameters {
        annotation = Type.Primitive "dict";
        number_of_parameters = 2;
      });
  assert_not_suppressed
    Source.Strict
    (Error.MissingTypeParameters {
        annotation = Type.Primitive "dict";
        number_of_parameters = 2;
      });

  let suppress_missing_return =
    Source.DefaultButDontCheck [Error.code (error (missing_return Type.Object))]
  in
  assert_suppressed suppress_missing_return (missing_return Type.integer);
  assert_suppressed suppress_missing_return (missing_return Type.Object);
  (* Defer to Default policy if not specifically suppressed *)
  assert_not_suppressed suppress_missing_return (incompatible_return_type Type.integer Type.float);
  assert_suppressed suppress_missing_return (Error.UndefinedName (Access.create "reveal_type"));

  (* Always suppress synthetic locations. *)
  assert_suppressed
    Source.Infer
    ~location:Location.Instantiated.synthetic
    (missing_return Type.integer);
  assert_suppressed
    Source.Declare
    ~location:Location.Instantiated.synthetic
    (missing_return Type.integer);
  assert_suppressed
    Source.Default
    ~location:Location.Instantiated.synthetic
    (missing_return Type.integer);
  assert_suppressed
    Source.Strict
    ~location:Location.Instantiated.synthetic
    (missing_return Type.integer)


let () =
  "error">:::[
    "due_to_analysis_limitations">::test_due_to_analysis_limitations;
    "due_to_mismatch_with_any">::test_due_to_mismatch_with_any;
    "join">::test_join;
    "filter">::test_filter;
    "suppress">::test_suppress;
  ]
  |> Test.run
