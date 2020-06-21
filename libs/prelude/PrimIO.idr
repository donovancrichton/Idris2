module PrimIO

import Builtin

public export
data IORes : Type -> Type where
     MkIORes : (result : a) -> (1 x : %World) -> IORes a

||| Idris's primitive IO, for building abstractions on top of.
public export
PrimIO : Type -> Type
PrimIO a = (1 x : %World) -> IORes a

export
data IO : Type -> Type where
     MkIO : (1 fn : PrimIO a) -> IO a

export
prim_io_pure : a -> PrimIO a
prim_io_pure x = \w => MkIORes x w

%inline
export
io_pure : a -> IO a
io_pure x = MkIO (\w => MkIORes x w)

export
prim_io_bind : (1 act : PrimIO a) -> (1 k : a -> PrimIO b) -> PrimIO b
prim_io_bind fn k w
    = let MkIORes x' w' = fn w in k x' w'

-- There's a special case for inlining this is Compiler.Inline, because
-- the inliner is cautious about case blocks at the moment. Once it's less
-- cautious, add an explicit %inline directive and take out the special case.
-- See also dealing with the newtype optimisation via %World in
-- Compiler.CompileExpr
export
io_bind : (1 act : IO a) -> (1 k : a -> IO b) -> IO b
io_bind (MkIO fn) k
    = MkIO (\w => let MkIORes x' w' = fn w
                      MkIO res = k x' in
                      res w')

-- A pointer representing a given parameter type
-- The parameter is a phantom type, to help differentiate between
-- different pointer types
public export
data Ptr : Type -> Type where [external]

-- A pointer to any type (representing a void* in foreign calls)
public export
data AnyPtr : Type where [external]

-- As Ptr, but associated with a finaliser that is run on garbage collection
public export
data GCPtr : Type -> Type where [external]

-- As AnyPtr, but associated with a finaliser that is run on garbage collection
public export
data GCAnyPtr : Type where [external]

public export
data ThreadID : Type where [external]

public export
data FArgList : Type where
     Nil : FArgList
     (::) : {a : Type} -> (1 arg : a) -> (1 args : FArgList) -> FArgList

export
%extern prim__cCall : (ret : Type) -> String -> (1 args : FArgList) ->
                      (1 x : %World) -> IORes ret
export
%extern prim__schemeCall : (ret : Type) -> String -> (1 args : FArgList) ->
                           (1 x : %World) -> IORes ret

export %inline
fromPrim : (1 fn : (1 x : %World) -> IORes a) -> IO a
fromPrim op = MkIO op

export %inline
toPrim : (1 act : IO a) -> PrimIO a
toPrim (MkIO fn) = fn

export %inline
schemeCall : (ret : Type) -> String -> (1 args : FArgList) -> IO ret
schemeCall ret fn args = fromPrim (prim__schemeCall ret fn args)

export %inline
cCall : (ret : Type) -> String -> FArgList -> IO ret
cCall ret fn args = fromPrim (prim__cCall ret fn args)

%foreign "C:idris2_isNull, libidris2_support"
export
prim__nullAnyPtr : AnyPtr -> Int

prim__forgetPtr : Ptr t -> AnyPtr
prim__forgetPtr = believe_me

export %inline
prim__nullPtr : Ptr t -> Int -- can't pass 'type' to a foreign function
prim__nullPtr p = prim__nullAnyPtr (prim__forgetPtr p)

unsafeCreateWorld : (1 f : (1 x : %World) -> a) -> a
unsafeCreateWorld f = f %MkWorld

unsafeDestroyWorld : (1 x : %World) -> a -> a
unsafeDestroyWorld %MkWorld x = x

export
unsafePerformIO : IO a -> a
unsafePerformIO (MkIO f)
    = unsafeCreateWorld (\w => case f w of
                               MkIORes res w' => unsafeDestroyWorld w' res)
