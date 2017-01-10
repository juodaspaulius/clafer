{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
module Language.Clafer.Front.AbsClafer where

-- Haskell module generated by the BNF converter


import Data.Data (Data,Typeable)
import GHC.Generics (Generic)
data Pos = Pos Integer Integer deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
noPos :: Pos
noPos = Pos 0 0

data Span = Span Pos Pos deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
noSpan :: Span
noSpan = Span noPos noPos

class Spannable n where getSpan :: n -> Span

instance Spannable n => Spannable [n] where
  getSpan (x:xs) = foldr (\item acc -> getSpan item >- acc ) (getSpan x) xs
  getSpan [] = noSpan

(>-) :: Span -> Span -> Span
(>-) (Span (Pos 0 0) (Pos 0 0)) s = s
(>-) r (Span (Pos 0 0) (Pos 0 0)) = r
(>-) (Span m _) (Span _ p) = Span m p

len :: [a] -> Integer
len = toInteger . length
newtype PosInteger = PosInteger ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosDouble = PosDouble ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosReal = PosReal ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosString = PosString ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosIdent = PosIdent ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosLineComment = PosLineComment ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosBlockComment = PosBlockComment ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosAlloy = PosAlloy ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
newtype PosChoco = PosChoco ((Int,Int),String)
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)
instance Spannable PosInteger where
  getSpan (PosInteger ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosDouble where
  getSpan (PosDouble ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosReal where
  getSpan (PosReal ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosString where
  getSpan (PosString ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosIdent where
  getSpan (PosIdent ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosLineComment where
  getSpan (PosLineComment ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosBlockComment where
  getSpan (PosBlockComment ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosAlloy where
  getSpan (PosAlloy ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
instance Spannable PosChoco where
  getSpan (PosChoco ((c, l), lex')) = 
    Span (Pos c' l') (Pos c' $ l' + len lex')
    where
      c' = toInteger c
      l' = toInteger l
data Module = Module Span [Declaration]
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Module where
    getSpan (Module s _ ) = s
data Declaration
    = EnumDecl Span PosIdent [EnumId] | ElementDecl Span Element
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Declaration where
    getSpan (EnumDecl s _ _ ) = s
    getSpan (ElementDecl s _ ) = s
data Clafer
    = Clafer Span Abstract GCard PosIdent Super Reference Card Init Elements
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Clafer where
    getSpan (Clafer s _ _ _ _ _ _ _ _ ) = s
data Constraint = Constraint Span [Exp]
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Constraint where
    getSpan (Constraint s _ ) = s
data Assertion = Assertion Span [Exp]
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Assertion where
    getSpan (Assertion s _ ) = s
data Goal
    = GoalMinDeprecated Span [Exp]
    | GoalMaxDeprecated Span [Exp]
    | GoalMinimize Span [Exp]
    | GoalMaximize Span [Exp]
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Goal where
    getSpan (GoalMinDeprecated s _ ) = s
    getSpan (GoalMaxDeprecated s _ ) = s
    getSpan (GoalMinimize s _ ) = s
    getSpan (GoalMaximize s _ ) = s
data Abstract = AbstractEmpty Span | Abstract Span
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Abstract where
    getSpan (AbstractEmpty s ) = s
    getSpan (Abstract s ) = s
data Elements = ElementsEmpty Span | ElementsList Span [Element]
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Elements where
    getSpan (ElementsEmpty s ) = s
    getSpan (ElementsList s _ ) = s
data Element
    = Subclafer Span Clafer
    | ClaferUse Span Name Card Elements
    | Subconstraint Span Constraint
    | Subgoal Span Goal
    | SubAssertion Span Assertion
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Element where
    getSpan (Subclafer s _ ) = s
    getSpan (ClaferUse s _ _ _ ) = s
    getSpan (Subconstraint s _ ) = s
    getSpan (Subgoal s _ ) = s
    getSpan (SubAssertion s _ ) = s
data Super = SuperEmpty Span | SuperSome Span Exp
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Super where
    getSpan (SuperEmpty s ) = s
    getSpan (SuperSome s _ ) = s
data Reference
    = ReferenceEmpty Span
    | ReferenceSet Span Exp
    | ReferenceBag Span Exp
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Reference where
    getSpan (ReferenceEmpty s ) = s
    getSpan (ReferenceSet s _ ) = s
    getSpan (ReferenceBag s _ ) = s
data Init = InitEmpty Span | InitSome Span InitHow Exp
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Init where
    getSpan (InitEmpty s ) = s
    getSpan (InitSome s _ _ ) = s
data InitHow = InitConstant Span | InitDefault Span
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable InitHow where
    getSpan (InitConstant s ) = s
    getSpan (InitDefault s ) = s
data GCard
    = GCardEmpty Span
    | GCardXor Span
    | GCardOr Span
    | GCardMux Span
    | GCardOpt Span
    | GCardInterval Span NCard
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable GCard where
    getSpan (GCardEmpty s ) = s
    getSpan (GCardXor s ) = s
    getSpan (GCardOr s ) = s
    getSpan (GCardMux s ) = s
    getSpan (GCardOpt s ) = s
    getSpan (GCardInterval s _ ) = s
data Card
    = CardEmpty Span
    | CardLone Span
    | CardSome Span
    | CardAny Span
    | CardNum Span PosInteger
    | CardInterval Span NCard
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Card where
    getSpan (CardEmpty s ) = s
    getSpan (CardLone s ) = s
    getSpan (CardSome s ) = s
    getSpan (CardAny s ) = s
    getSpan (CardNum s _ ) = s
    getSpan (CardInterval s _ ) = s
data NCard = NCard Span PosInteger ExInteger
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable NCard where
    getSpan (NCard s _ _ ) = s
data ExInteger = ExIntegerAst Span | ExIntegerNum Span PosInteger
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable ExInteger where
    getSpan (ExIntegerAst s ) = s
    getSpan (ExIntegerNum s _ ) = s
data Name = Path Span [ModId]
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Name where
    getSpan (Path s _ ) = s
data Exp
    = EDeclAllDisj Span Decl Exp
    | EDeclAll Span Decl Exp
    | EDeclQuantDisj Span Quant Decl Exp
    | EDeclQuant Span Quant Decl Exp
    | EImpliesElse Span Exp Exp Exp
    | EIff Span Exp Exp
    | EImplies Span Exp Exp
    | EOr Span Exp Exp
    | EXor Span Exp Exp
    | EAnd Span Exp Exp
    | ENeg Span Exp
    | ELt Span Exp Exp
    | EGt Span Exp Exp
    | EEq Span Exp Exp
    | ELte Span Exp Exp
    | EGte Span Exp Exp
    | ENeq Span Exp Exp
    | EIn Span Exp Exp
    | ENin Span Exp Exp
    | EQuantExp Span Quant Exp
    | EAdd Span Exp Exp
    | ESub Span Exp Exp
    | EMul Span Exp Exp
    | EDiv Span Exp Exp
    | ERem Span Exp Exp
    | EGMax Span Exp
    | EGMin Span Exp
    | ESum Span Exp
    | EProd Span Exp
    | ECard Span Exp
    | EMinExp Span Exp
    | EDomain Span Exp Exp
    | ERange Span Exp Exp
    | EUnion Span Exp Exp
    | EUnionCom Span Exp Exp
    | EDifference Span Exp Exp
    | EIntersection Span Exp Exp
    | EIntersectionDeprecated Span Exp Exp
    | EJoin Span Exp Exp
    | ClaferId Span Name
    | EInt Span PosInteger
    | EDouble Span PosDouble
    | EReal Span PosReal
    | EStr Span PosString
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Exp where
    getSpan (EDeclAllDisj s _ _ ) = s
    getSpan (EDeclAll s _ _ ) = s
    getSpan (EDeclQuantDisj s _ _ _ ) = s
    getSpan (EDeclQuant s _ _ _ ) = s
    getSpan (EImpliesElse s _ _ _ ) = s
    getSpan (EIff s _ _ ) = s
    getSpan (EImplies s _ _ ) = s
    getSpan (EOr s _ _ ) = s
    getSpan (EXor s _ _ ) = s
    getSpan (EAnd s _ _ ) = s
    getSpan (ENeg s _ ) = s
    getSpan (ELt s _ _ ) = s
    getSpan (EGt s _ _ ) = s
    getSpan (EEq s _ _ ) = s
    getSpan (ELte s _ _ ) = s
    getSpan (EGte s _ _ ) = s
    getSpan (ENeq s _ _ ) = s
    getSpan (EIn s _ _ ) = s
    getSpan (ENin s _ _ ) = s
    getSpan (EQuantExp s _ _ ) = s
    getSpan (EAdd s _ _ ) = s
    getSpan (ESub s _ _ ) = s
    getSpan (EMul s _ _ ) = s
    getSpan (EDiv s _ _ ) = s
    getSpan (ERem s _ _ ) = s
    getSpan (EGMax s _ ) = s
    getSpan (EGMin s _ ) = s
    getSpan (ESum s _ ) = s
    getSpan (EProd s _ ) = s
    getSpan (ECard s _ ) = s
    getSpan (EMinExp s _ ) = s
    getSpan (EDomain s _ _ ) = s
    getSpan (ERange s _ _ ) = s
    getSpan (EUnion s _ _ ) = s
    getSpan (EUnionCom s _ _ ) = s
    getSpan (EDifference s _ _ ) = s
    getSpan (EIntersection s _ _ ) = s
    getSpan (EIntersectionDeprecated s _ _ ) = s
    getSpan (EJoin s _ _ ) = s
    getSpan (ClaferId s _ ) = s
    getSpan (EInt s _ ) = s
    getSpan (EDouble s _ ) = s
    getSpan (EReal s _ ) = s
    getSpan (EStr s _ ) = s
data Decl = Decl Span [LocId] Exp
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Decl where
    getSpan (Decl s _ _ ) = s
data Quant
    = QuantNo Span
    | QuantNot Span
    | QuantLone Span
    | QuantOne Span
    | QuantSome Span
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable Quant where
    getSpan (QuantNo s ) = s
    getSpan (QuantNot s ) = s
    getSpan (QuantLone s ) = s
    getSpan (QuantOne s ) = s
    getSpan (QuantSome s ) = s
data EnumId = EnumIdIdent Span PosIdent
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable EnumId where
    getSpan (EnumIdIdent s _ ) = s
data ModId = ModIdIdent Span PosIdent
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable ModId where
    getSpan (ModIdIdent s _ ) = s
data LocId = LocIdIdent Span PosIdent
  deriving (Eq, Ord, Show, Read, Data, Typeable, Generic)

instance Spannable LocId where
    getSpan (LocIdIdent s _ ) = s
