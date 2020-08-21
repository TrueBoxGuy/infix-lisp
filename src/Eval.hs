{-# LANGUAGE GeneralizedNewtypeDeriving, LambdaCase, PatternSynonyms #-}
module Eval where


import           Parse
import qualified Data.List                     as L
import           Data.Maybe                     ( fromMaybe )
import           Data.Bifunctor                 ( bimap
                                                , second
                                                )


data Value = VPrim Primitive | VFunction Function deriving (Show)
data Primitive = VNum Int | VStr String | VNil deriving (Show)
data Function = Builtin (Value -> Value -> IO Value) | Lambda String NExp String

pattern PatNum a = VPrim (VNum a)
pattern PatStr a = VPrim (VStr a)
pattern PatLambda a b c = VFunction (Lambda a b c)
pattern PatBuiltin f = VFunction (Builtin f)

instance Show Function where
  show (Builtin _        ) = "builtin"
  show (Lambda a1 body a2) = unwords ["[", a1, show body, a2, "]"]

newtype Env = Env [(String , Value)] deriving (Show, Semigroup, Monoid)



runFunction :: Function -> Env -> Value -> Value -> IO Value
runFunction (Builtin f) _ arg1 arg2 = f arg1 arg2
runFunction (Lambda argName1 exp argName2) env arg1 arg2 =
  evalExp (env <> Env [(argName1, arg1), (argName2, arg2)]) exp



builtins :: [(String, Function)]
builtins =
  [ ("+"    , Builtin builtinPlus)
  , ("-"    , Builtin builtinMinus)
  , ("print", Builtin builtinPrint)
  ]
 where
  builtinPlus (PatNum a) (PatNum b) = pure . PatNum $ a + b
  builtinPlus (PatStr a) (PatStr b) = pure . PatStr $ a ++ b
  builtinPlus a b = illegalFunctionArguments "+" [a, b]

  builtinMinus (PatNum a) (PatNum b) = pure . PatNum $ a - b
  builtinMinus a b = illegalFunctionArguments "-" [a, b]

  builtinPrint _ a = print a >> pure (VPrim VNil)
  --builtinPrint _ a illegalFunctionArguments "print" [a]



illegalFunctionArguments :: String -> [Value] -> a
illegalFunctionArguments functionName args =
  error $ functionName ++ " called with illegal arguments " ++ show args


evalExp :: Env -> NExp -> IO Value
evalExp env expression = case expression of
  (ExpLit   lit          ) -> pure $ fromLiteral lit
  (ExpIdent (Ident ident)) -> pure $ envLookup env ident
  (ExpLambda (Ident argName1) body (Ident argName2)) ->
    pure $ VFunction $ Lambda argName1 body argName2
  (ExpInvocation arg1 exp arg2) -> evalExp env exp >>= \case
    VFunction func -> do
      res1 <- evalExp env arg1
      res2 <- evalExp env arg2
      runFunction func env res1 res2
    wannabeFunction -> error $ show wannabeFunction ++ " is not a function"



fromLiteral :: NLiteral -> Value
fromLiteral (StringLit s) = VPrim $ VStr s
fromLiteral (IntLit    n) = VPrim $ VNum n

envLookup :: Env -> String -> Value
envLookup (Env env) name = maybe (VPrim VNil) snd
  $ L.find (\(n, _) -> n == name) envWithBuiltins
  where envWithBuiltins = env ++ map (second VFunction) builtins

orNil :: Maybe Value -> Value
orNil = fromMaybe (VPrim VNil)


getName :: NIdent -> String
getName (Ident s) = s
