{-
 Copyright (C) 2012 Kacper Bak, Jimmy Liang <http://gsd.uwaterloo.ca>

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
-}
-- | Generates a XML representation of IR conforming to the ClaferIR.xsd.
module Language.Clafer.Generator.Xml where

-- import Text.XML.HaXml.XmlContent.Haskell hiding (Result)

import Language.Clafer.Common
import Language.Clafer.Front.AbsClafer
import Language.Clafer.Intermediate.Intclafer

tag :: String -> String -> String
tag name exp' = concat ["<", name, ">", exp', "</", name, ">\n"]

optTag :: Maybe a -> (a -> String) -> String
optTag ele f = maybe "" f ele

tagType :: String -> String -> String -> String
tagType name typename exp' = opening ++ rest
  where
  opening = concat ["<", name, " xsi:type=\"cl:", typename, "\""]
  rest
    | null exp'  = " />"
    | otherwise = concat [">", exp', "</", name, ">"]

genXmlInteger :: Integer -> String
genXmlInteger n = tag "IntLiteral" $ show n

genXmlBoolean :: String -> Bool -> String
genXmlBoolean label b = tag label $ toLowerS $ show b

genXmlString :: String -> String
genXmlString str = tag "StringLiteral" str

genXmlIntPair :: (Integer, Integer) -> String
genXmlIntPair (x, y) = concat
  [ genXmlInteger x
  , genXmlInteger y]

-- | Generate an XML representation of the IR
genXmlModule :: IModule -> Result
genXmlModule imodule = concat
  [ "<?xml version=\"1.0\"?>"
  , "<Module xmlns=\"http://clafer.org/ir\""
  , " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""
  , " xmlns:cl=\"http://clafer.org/ir\""
  , " xsi:schemaLocation=\"http://clafer.org/ir https://github.com/gsdlab/clafer/blob/master/src/ClaferIR.xsd\">"
  , tag "Name" $ _mName imodule
  , concatMap genXmlElement $ _mDecls imodule
  , "</Module>"]


genXmlClafer :: IClafer -> Result
genXmlClafer x = case x of
  IClafer pos modifiers' gcrd id' uid' puid' super' reference' crd glcard _ es  ->
    concat [ tag "Position" $ genXmlPosition pos
           , genXmlAbstract $ _abstract modifiers'
           , optTag gcrd genXmlGCard
           , genXmlId id'
           , genXmlUid uid'
           , genXmlParentUid puid'
           , genXmlSuper super'
           , genXmlReference reference'
           , optTag crd genXmlCard
           , genXmlGlCard glcard -- TODO serialize mutability details
           , concatMap genXmlElement es]

genXmlAbstract :: Bool -> String
genXmlAbstract isAbs = genXmlBoolean "IsAbstract" isAbs

genXmlGCard :: IGCard -> String
genXmlGCard (IGCard isKeyword' interval') = tag "GroupCard" $ concat
  [ genXmlBoolean "IsKeyword" isKeyword'
  , tag "Interval" $ genXmlInterval interval']

genXmlInterval :: (Integer, Integer) -> String
genXmlInterval (nMin, nMax) = concat
  [ tag "Min" $ genXmlInteger nMin
  , tag "Max" $ genXmlInteger nMax]

genXmlId :: String -> String
genXmlId ident' = tag "Id" ident'

genXmlUid :: String -> String
genXmlUid uid' = tag "UniqueId" uid'

genXmlParentUid :: String -> String
genXmlParentUid uid' = tag "ParentUniqueId" uid'

genXmlSuper :: Maybe PExp -> String
genXmlSuper x = case x of
  Nothing                 -> ""
  Just pexp' -> genXmlPExp "Super" pexp'

genXmlReference :: Maybe IReference -> String
genXmlReference x = case x of
  Nothing                 -> ""
  Just (IReference isSet' pexp') -> tag "Reference" $ concat
    [ genXmlBoolean "IsSet" isSet'
    , genXmlPExp "Ref" pexp']

genXmlCard :: (Integer, Integer) -> String
genXmlCard interval' = tag "Card" $ genXmlInterval interval'

genXmlGlCard :: (Integer, Integer) -> String
genXmlGlCard interval' = tag "GlobalCard" $ genXmlInterval interval'

genXmlElement :: IElement -> String
genXmlElement x = case x of
  IEClafer clafer  -> tagType "Declaration" "IClafer" $ genXmlClafer clafer
  IEConstraint isHard' pexp  -> tagType "Declaration" "IConstraint" $ concat
                         [ genXmlBoolean "IsHard" isHard'
                         , genXmlPExp "ParentExp" pexp]
  IEGoal isMaximize' pexp -> tagType "Declaration" "IGoal" $ concat
                         [ genXmlBoolean "IsMaximize" isMaximize'
                         , genXmlPExp "ParentExp" pexp]


genXmlAnyOp :: (a -> String) -> (a -> String) -> [(String, a)] -> String
genXmlAnyOp ft f xs = concatMap
  (\(tname, texp) -> tagType tname (ft texp) $ f texp) xs

genXmlPExp :: String -> PExp -> String
genXmlPExp tagName (PExp iType' pid' pos' iexp) = tag tagName $ concat
  [ optTag iType' genXmlIType
  , tag "ParentId" pid'
  , tag "Position" $ genXmlPosition pos'
  , tagType "Exp" (genXmlIExpType iexp) $ genXmlIExp iexp]

genXmlPosition :: Span -> String
genXmlPosition (Span (Pos s1 s2) (Pos e1 e2)) = concat
  [ tag "Start" $ genXmlIntPair (s1, s2)
  , tag "End"   $ genXmlIntPair (e1, e2)]

genXmlIExpType :: IExp -> String
genXmlIExpType x = case x of
  IDeclPExp _ _ _ -> "IDeclarationParentExp"
  IFunExp _ _ -> "IFunctionExp"
  IInt _ -> "IIntExp"
  IDouble _ -> "IDoubleExp"
  IStr _ -> "IStringExp"
  IClaferId _ _ _ _ -> "IClaferId"

genXmlIExp :: IExp -> String
genXmlIExp x = case x of
  IDeclPExp quant' decls' pexp -> concat
    [ tagType "Quantifier" (genXmlQuantType quant') ""
    , concatMap genXmlDecl decls'
    , genXmlPExp "BodyParentExp" pexp]
  IFunExp op' exps' -> concat
    [ tag "Operation" $ concatMap escape op'
    , concatMap (genXmlPExp "Argument") exps']
    where
    escape '\"' = "&quot;"
    escape '\'' = "&apos;"
    escape '<'  = "&lt;"
    escape '>'  = "&gt;"
    escape '&'  = "&amp;"
    escape y    = [y]
  IInt n -> genXmlInteger n
  IDouble n -> tag "DoubleLiteral" $ show n
  IStr str -> genXmlString str
  IClaferId modName' sident' isTop' bind' -> concat
    [ tag "ModuleName" modName'
    , tag "Id" sident'
    , genXmlBoolean "IsTop" isTop'
    , tag "Bind" $ getClaferBindString bind']

getClaferBindString :: ClaferBinding -> String
getClaferBindString bind' = case bind' of
                                 (GlobalBind uid') -> uid'
                                 _ -> ""

genXmlDecl :: IDecl -> String
genXmlDecl (IDecl disj locids pexp) = tag "Declaration" $ concat
  [ genXmlBoolean "IsDisjunct" disj
  , concatMap (tag "LocalDeclaration") locids
  , genXmlPExp "Body" pexp]

genXmlQuantType :: IQuant -> String
genXmlQuantType x = case x of
  INo   -> "INo"
  ILone -> "ILone"
  IOne  -> "IOne"
  ISome -> "ISome"
  IAll  -> "IAll"

genXmlITypeType :: IType -> String
genXmlITypeType x = case x of
  TBoolean -> "IBoolean"
  TString -> "IString"
  TInteger -> "IInteger"
  TReal -> "IReal"
  TClafer _ -> "ISet"

genXmlIType :: IType -> String
genXmlIType x = tagType "Type" (genXmlITypeType x) ""
