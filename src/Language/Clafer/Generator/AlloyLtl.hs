{-# LANGUAGE RankNTypes, FlexibleContexts #-}
{-
 Copyright (C) 2012-2013 Kacper Bak, Jimmy Liang, Rafael Olaechea <http://gsd.uwaterloo.ca>

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
-- | Generates Alloy4.1 or 4.2 code for a Clafer model
module Language.Clafer.Generator.AlloyLtl (genAlloyLtlModule) where

import Control.Applicative ((<$>))
import Control.Lens hiding (elements, mapping, op)
import Control.Monad.State
import Data.List
import Data.Maybe
import Data.StringMap (StringMap)
import qualified Data.StringMap as SMap

import Language.Clafer.Common
import Language.Clafer.ClaferArgs
import Language.Clafer.Front.Absclafer
import Language.Clafer.Generator.Concat
import Language.Clafer.Intermediate.Intclafer hiding (exp)
--import Debug.Trace

data GenCtx = GenCtx {
    resPath::[String],
    time :: Maybe String
  } deriving (Show)

data GenEnv = GenEnv
  { claferargs :: ClaferArgs
  , uidIClaferMap :: StringMap IClafer
  }  deriving (Show)

timeSig :: String
timeSig = "Time"

bOrFoldl1 :: [Bool] -> Bool
bOrFoldl1 [] = False
bOrFoldl1 xs = foldl1 (\res val -> res || val) xs

-- Alloy code generation
-- 07th Mayo 2012 Rafael Olaechea
--      Added Logic to print a goal block in case there is at least one goal.
genAlloyLtlModule :: ClaferArgs -> (IModule, GEnv) -> [(UID, Integer)] -> StringMap IClafer -> (Result, [(Span, IrTrace)])
genAlloyLtlModule    claferargs'    (imodule, _)       scopes             uidIClaferMap'   = (flatten output, filter ((/= NoTrace) . snd) $ mapLineCol output)
  where
  genEnv = GenEnv claferargs' uidIClaferMap'
  rootClafer = IEClafer $ IClafer noSpan (IClaferModifiers False True True) (Just $ IGCard False (0, -1)) "root" "root" "" Nothing Nothing (Just (1,1)) (1, 1) False (_mDecls imodule)
  -- output = header claferargs scopes +++ (cconcat $ map (genDeclaration genEnv) (_mDecls imodule)) +++
  output = header claferargs' scopes +++ (genDeclaration genEnv rootClafer) +++
       if ((not $ skip_goals claferargs') && length goals_list > 0) then
                CString "objectives o_global {\n" +++   (cintercalate (CString ",\n") goals_list) +++   CString "\n}"
       else
                CString ""
       where
                goals_list = filterNull (map (genDeclarationGoalsOnly genEnv) (_mDecls imodule))

header :: ClaferArgs -> [(UID, Integer)] -> Concat
header    args          scopes       = CString $ unlines
    [ if Alloy42 `elem` (mode args) then "" else "open util/integer"
    , if AlloyLtl `elem` (mode args) then "open util/ordering[Time]" else ""
    , "pred show {}"
    , if (validate args) ||  (noalloyruncommand args)
      then ""
      else mkScope
    , ""
    , behavioralSigs
    ]
    where
      mkScope = if AlloyLtl `elem` (mode args)
      then
        "run show for 10" -- ++ show (fixed_scope args)
      else
        "run show for 1" ++ genScopes scopes
      genScopes [] = ""
      genScopes scopes' = " but " ++ intercalate ", " (map genScope scopes')
      behavioralSigs = unlines [
        "sig Time {loop: lone Time}",
        "fact Loop {loop in last->Time}"]

genScope :: (UID, Integer) -> String
genScope    (uid', scope)       = show scope ++ " " ++ uid'


-- 07th Mayo 2012 Rafael Olaechea
-- Modified so that we can collect all goals into a single block as required per the way goals are handled in modified alloy.
genDeclarationGoalsOnly :: GenEnv -> IElement -> Concat
genDeclarationGoalsOnly    genEnv    x         = case x of
  IEClafer _  -> CString ""
  IEConstraint _ _  -> CString ""
  IEGoal _ (PExp _ _ _ innerexp) -> case innerexp of
        IFunExp op' (e:_) ->  if  op' == iGMax || op' == iGMin then
                        mkMetric op' $ genPExp genEnv (GenCtx [] Nothing) e
                else
                        error "unary operator  distinct from (min/max) at the topmost level of a goal element"
        _ ->  error "no unary operator (min/max) at the topmost level of a goal element."

-- 07th Mayo 2012 Rafael Olaechea
-- Removed goal from this function as they will now  all be collected into a single block.
genDeclaration :: GenEnv -> IElement -> Concat
genDeclaration genEnv x = case x of
  IEClafer clafer'  -> genClafer genEnv [] clafer'
  IEConstraint _ pexp  -> mkFact $ genPExp genEnv (GenCtx [] Nothing) pexp
  IEGoal _ (PExp _ _ _ innerexp) -> case innerexp of
        IFunExp op'  _ ->  if  op' == iGMax || op' == iGMin then
                       CString ""
                else
                        error "unary operator  distinct from (min/max) at the topmost level of a goal element"
        _ ->  error "no unary operator (min/max) at the topmost level of a goal element."

mkFact :: Concat -> Concat
mkFact  xs = cconcat [CString "fact ", mkSet xs, CString "\n"]

mkMetric :: String -> Concat -> Concat
mkMetric goalopname xs = cconcat [ if goalopname == iGMax then CString "maximize" else  CString "minimize", CString " ", xs, CString " "]

mkSet :: Concat -> Concat
mkSet xs = cconcat [CString "{ ", xs, CString " }"]

showSet :: Concat -> [Concat] -> Concat
showSet delim xs = showSet' delim $ filterNull xs
  where
  showSet' _ []     = CString "{}"
  showSet' delim' xs' = mkSet $ cintercalate delim' xs'

optShowSet :: [Concat] -> Concat
optShowSet [] = CString ""
optShowSet xs = CString "\n" +++ showSet (CString "\n  ") xs

-- optimization: top level cardinalities
-- optimization: if only boolean parents, then set card is known
genClafer :: GenEnv -> [String] -> IClafer -> Concat
genClafer genEnv resPath' clafer'
  = (cunlines $ filterNull
      [   cardFact
      +++ claferDecl clafer' (
          (showSet (CString "\n, ") $ genRelations genEnv clafer')
          +++ (optShowSet $ filterNull $ genConstraints genEnv (GenCtx resPath' Nothing) clafer')
        )
      ]
    )
  +++ CString "\n"
  +++ children'
  where
  children' = cconcat $ filterNull $ map
             (genClafer genEnv ((_uid clafer') : resPath')) $
             getSubclafers $ _elements clafer'
  cardFact
    | null resPath' && (null $ flatten $ genOptCard clafer') =
        case genCard (_uid clafer') $ _card clafer' of
          CString "set" -> CString ""
          c -> mkFact c
    | otherwise = CString ""

claferDecl :: IClafer -> Concat -> Concat
claferDecl    c     rest    = cconcat
  [ genSigCard
  , CString $ genAbstract $ _isAbstract c
  , CString "sig "
  , Concat NoTrace [CString $ _uid c, genExtends $ _super c, CString "\n", rest]
  ]
  where
  genSigCard = if not (_mutable c) then genOptCard c else CString ""
  genAbstract isAbs = if isAbs then "abstract " else ""
  genExtends Nothing = CString ""
  genExtends (Just (PExp _ _ _ (IClaferId _ i _ _))) = CString " " +++ Concat NoTrace [CString $ "extends " ++ i]
  -- todo: handle multiple inheritance
  genExtends _ = CString ""

genOptCard :: IClafer -> Concat
genOptCard    c
  | glCard' `elem` ["lone", "one", "some"] = cardConcat (_uid c) False [CString glCard'] +++ (CString " ")
  | otherwise                              = CString ""
  where
  glCard' = genIntervalCrude $ _glCard c


-- -----------------------------------------------------------------------------
-- overlapping inheritance is a new clafer with val (unlike only relation)
-- relations: overlapping inheritance (val rel), children
-- adds parent relation
-- 29/March/2012  Rafael Olaechea: ref is now prepended with clafer name to be able to refer to it from partial instances.
genRelations :: GenEnv -> IClafer -> [Concat]
genRelations    genEnv    c        = ownRef ++ (map mkRel $ getSubclafers $ _elements c)
  where
    ownRef = if isJust $ _reference c
             then [ CString $ genRel (if (noalloyruncommand (claferargs genEnv)) then  (_uid c ++ "_ref") else "ref")
                    c {_card = Just (1, 1)} $
                    flatten $ refType genEnv c
                  ]
             else []
    mkRel c' = Concat NoTrace [CString $ genRel (genRelName $ _uid c') c' $ _uid c']

genRelName :: String -> String
genRelName name = "r_" ++ name

-- trace ("----- genRel ----\n" ++ show c) $
genRel :: String -> IClafer -> String -> String
genRel name c rType = if _mutable c
  then genMutAlloyRel name rType'
  else genAlloyRel name (genCardCrude $ _card c) rType'
  where
  rType' = if isPrimitive rType then "Int" else rType


genAlloyRel :: String -> String -> String -> String
genAlloyRel name card' rType = concat [name, " : ", card', " ", rType]

genMutAlloyRel :: String -> String -> String
genMutAlloyRel name rType = concat [name, " : ", rType, " -> ", timeSig]

refType :: GenEnv -> IClafer -> Concat
refType    genEnv c = fromMaybe (CString "") $ fmap ((genType genEnv).getTarget) $ _ref <$> _reference c


getTarget :: PExp -> PExp
getTarget    x     = case x of
  PExp _ _ _ (IFunExp op' (_:pexp:_))  -> if op' == iJoin then pexp else x
  _ -> x

genType :: GenEnv -> PExp                              -> Concat
genType    genEnv    x@(PExp _ _ _ y@(IClaferId _ _ _ _)) = genPExp genEnv (GenCtx [] Nothing)
  x{_exp = y{_isTop = True}}
genType    genEnv    x = genPExp genEnv (GenCtx [] Nothing) x


-- -----------------------------------------------------------------------------
-- constraints
-- user constraints + parent + group constraints + reference
-- a = NUMBER do all x : a | x = NUMBER (otherwise alloy sums a set)

containsTimedRel :: GenEnv ->  PExp -> Bool
containsTimedRel    genEnv     (PExp iType' _ _ exp') =  case exp' of
  IFunExp _ exps' -> bOrFoldl1 $ map (containsTimedRel genEnv) exps'
  IClaferId _ sident' _ (Just bind) -> timedIClaferId
    where
    boundIClafer = fromJust $ SMap.lookup bind (uidIClaferMap genEnv)
    mutable' = _mutable boundIClafer
    timedIClaferId
      | sident' == "ref" = mutable'
      | head sident' == '~' = False
      | isNothing iType' = mutable'
      | otherwise = case fromJust $ iType' of
        TInteger -> False
        TReal -> False
        TString -> False
        _ -> mutable'
  IDeclPExp _ decls' e -> bOrFoldl1 (map (containsMut genEnv) decls') || containsTimedRel genEnv e
  _ -> False
  where
  containsMut genEnv' (IDecl _ _ body') = containsTimedRel genEnv' body'

genConstraints :: GenEnv -> GenCtx -> IClafer -> [Concat]
genConstraints    genEnv    ctx       c
  = (genParentConst (resPath ctx) c)
  : (genMutSubClafersConst genEnv c)
  : (genGroupConst c)
  : (genPathConst genEnv ctx  (if (noalloyruncommand (claferargs genEnv)) then  (_uid c ++ "_ref") else "ref") c)
  : constraints
  where
  constraints = concat $ map genConst $ _elements c
  genConst :: IElement -> [ Concat ]
  genConst    x = case x of
    IEConstraint _ pexp  -> -- genPExp cargs ((_uid c) : resPath) pexp
        if containsTimedRel genEnv pexp
        then [genTimeDecl "t" (resPath ctx) c, genPExp genEnv ctx { time = Just "t", resPath = ((_uid c) : (resPath ctx))} pexp]
        else [genPExp genEnv ctx { time = Nothing, resPath = ((_uid c) : (resPath ctx))} pexp]
    IEClafer c' ->
        (if genCardCrude (_card c') `elem` ["one", "lone", "some"]
         then CString ""
         else mkCard ({- do not use the genRelName as the constraint name -} _uid c') False (genRelName $ _uid c') $ fromJust (_card c')
        ) : genSetUniquenessConstraint c'
    IEGoal _ _ -> error "getConst function from Alloy generator was given a Goal, this function should only be given a Constrain or Clafer" -- This should never happen

-- generates time variable binding declaration which appears as a first expression in mutable constraints
-- it references all time moments when context clafer instance is active
-- typical binding form is: this.(ParentSig.ContextClaferRelation)
{- OLD: genTimeDecl tvar ctx c = CString ("all " ++ tvar ++ " : (this.(" ++ head (resPath ctx)  ++ ".@" ++ genRelName (_uid c) ++ ")) | " )-}
-- one first <: Time |
-- Sample template
-- let local_next = (this.(c0_a.@r_c0_b)) <: next | one t : Time | one t <: local_next and no local_next :> t
-- if defined under root clafer:
-- one t: first <: Time |
genTimeDecl :: String -> [String] -> IClafer -> Concat
genTimeDecl tvar rPath c = CString $  case rPath of
                                           x:_ -> localNextDecl x ++ firstDecl ++ " and "
                                           [] -> "one " ++ tvar ++ " : first <: " ++ timeSig ++ " | " -- For top level constraint
  where
  localNextDecl ctxSig = "let local_next = (this.(" ++ ctxSig ++ ".@" ++ genRelName (_uid c) ++ ")) <: next "
  firstDecl = " | one " ++ tvar ++ " : " ++ timeSig ++ firstConstr
  firstConstr = " | one " ++ tvar ++ " <: local_next and no local_next :> " ++ tvar

-- generates cardinality constraints for mutable subclafers
-- typically all t: Time | lone r_field.t
-- Michal: TODO: revise because now a clafer can have both super and reference at the same time
genMutSubClafersConst :: GenEnv -> IClafer -> Concat
genMutSubClafersConst    genEnv c = genTimeQuant allSubExp +++ (cintercalate (CString " && ") allSubExp)
  where
  allSubExp = map genMutCardConst mutClafers ++ refCardConst
  refCardConst
    | (_mutable c) && (isJust $ _reference c) = [CString $ "one this.@" ++ (refRelName c) ++ ".t"]
    | otherwise = []
  mutClafers = filter isMutableNonRef $ getSubclafers $ _elements c
  isMutableNonRef c' = (_mutable c') && (cardStr c' /= "set")  -- Michal: does not matter whether a ref or not or whether has super or not
  cardStr c' = genCardCrude $ _card c'
  genTimeQuant [] = CString ""
  genTimeQuant _ = genTimeAllQuant "t"
  genMutCardConst c' = CString $ (cardStr c') ++ " " ++ (genRelName $ _uid c') ++ ".t"
  refRelName c' = (if (noalloyruncommand (claferargs genEnv)) then  (_uid c' ++ "_ref") else "ref")


genSetUniquenessConstraint :: IClafer -> [Concat]
genSetUniquenessConstraint c =
    (case _reference c of
      Just (IReference True _) ->
        (case _card c of
            Just (lb,  ub) -> if (lb > 1 || ub > 1 || ub == -1)
              then [ CString $ (
                        (case isTopLevel c of
                          False -> "all disj x, y : this.@" ++ (genRelName $ _uid c)
                          True  -> " all disj x, y : "       ++ (_uid c)))
                      ++ " | (x.@ref) != (y.@ref) "
                   ]
              else []
            _ -> [])
      _ -> []
    )


-- optimization: if only boolean features then the parent is unique
genParentConst :: [String] -> IClafer -> Concat
genParentConst [] _     = CString ""
genParentConst _ c = genOptParentConst c

genOptParentConst :: IClafer -> Concat
genOptParentConst    c
  | glCard' == "one"         = CString ""
  | glCard' == "lone" && mut = Concat NoTrace [genTimeAllQuant "t", CString $ "one " ++ rel ++ ".t"]
  | glCard' == "lone"        = Concat NoTrace [CString $ "one " ++ rel]
  | mut                      = Concat NoTrace [genTimeAllQuant "t", CString $ "one @" ++ rel ++ ".t.this"]
  | otherwise                = Concat NoTrace [CString $ "one @" ++ rel ++ ".this"]
  -- eliminating problems with cyclic containment;
  -- should be added to cases when cyclic containment occurs
  --                    , " && no iden & @", rel, " && no ~@", rel, " & @", rel]
  where
  mut = _mutable c
  rel = genRelName $ _uid c
  glCard' = genIntervalCrude $ _glCard c

genGroupConst :: IClafer -> Concat
genGroupConst    clafer'
  | null children' || flatten card' == "" = CString ""
  | otherwise = cconcat [genTimeQuant, CString "let children = ", brArg id $ CString children', CString " | ", card']
  where
  subclafers = getSubclafers $ _elements clafer'
  children' = intercalate " + " $ map childRel subclafers
  childRel :: IClafer -> String
  childRel subc = (genRelName._uid) subc ++ (if _mutable subc then ".t" else "")
  card'     = mkCard (_uid clafer') True "children" $ _interval $ fromJust $ _gcard $ clafer'
  genTimeQuant = if any _mutable subclafers then genTimeAllQuant "t" else CString ""

mkCard :: String -> Bool -> String -> (Integer, Integer) -> Concat
mkCard constraintName group' element' crd
  | crd' == "set" || crd' == ""        = CString ""
  | crd' `elem` ["one", "lone", "some"] = CString $ crd' ++ " " ++ element'
  | otherwise                            = interval'
  where
  interval' = genInterval constraintName group' element' crd
  crd'  = flatten $ interval'

-- generates expression for references that point to expressions (not single clafers)
genPathConst :: GenEnv -> GenCtx ->  String -> IClafer -> Concat
genPathConst    genEnv    ctx        name      c
  | isRefPath (c ^. reference) = cconcat [CString name, CString " = ",
                                  fromMaybe (error "genPathConst: impossible.") $
                                  fmap ((brArg id).(genPExp genEnv ctx)) $
                                  _ref <$> _reference c]
  | otherwise = CString ""

isRefPath :: Maybe IReference -> Bool
isRefPath Nothing = False
isRefPath (Just IReference{_ref=s}) = not $ isSimplePath s

isSimplePath :: PExp -> Bool
isSimplePath    (PExp _ _ _ (IClaferId _ _ _ _)) = True
isSimplePath    (PExp _ _ _ (IFunExp op' _)) = op' == iUnion
isSimplePath    _ = False

-- -----------------------------------------------------------------------------
-- Not used?
-- genGCard element gcard = genInterval element  $ interval $ fromJust gcard


genCard :: String -> Maybe Interval -> Concat
genCard    element'   crd            = genInterval element' False element' $ fromJust crd

genCardCrude :: Maybe Interval -> String
genCardCrude crd = genIntervalCrude $ fromJust crd

genIntervalCrude :: Interval -> String
genIntervalCrude x = case x of
  (1, 1)  -> "one"
  (0, 1)  -> "lone"
  (1, -1) -> "some"
  _       -> "set"


genInterval :: String      -> Bool -> String -> Interval -> Concat
genInterval    constraintName group'   element'   x         = case x of
  (1, 1) -> cardConcat constraintName group' [CString "one"]
  (0, 1) -> cardConcat constraintName group' [CString "lone"]
  (1, -1)   -> cardConcat constraintName group' [CString "some"]
  (0, -1)   -> CString "set" -- "set"
  (n, exinteger)  ->
    case (s1, s2) of
      (Just c1, Just c2) -> cconcat [c1, CString " and ", c2]
      (Just c1, Nothing) -> c1
      (Nothing, Just c2) -> c2
      (Nothing, Nothing) -> undefined
    where
    s1 = if n == 0 then Nothing else Just $ cardLowerConcat constraintName group' [CString $ concat [show n, " <= #",  element']]
    s2 =
        do
            result <- genExInteger element' x exinteger
            return $ cardUpperConcat constraintName group' [CString result]


cardConcat :: String        -> Bool -> [Concat] -> Concat
cardConcat    constraintName = Concat . ExactCard constraintName


cardLowerConcat :: String        -> Bool -> [Concat] -> Concat
cardLowerConcat    constraintName = Concat . LowerCard constraintName


cardUpperConcat :: String        -> Bool -> [Concat] -> Concat
cardUpperConcat    constraintName = Concat . UpperCard constraintName


genExInteger :: String -> Interval -> Integer -> Maybe Result
genExInteger    element'  (y,z) x  =
  if (y==0 && z==0) then Just $ concat ["#", element', " = ", "0"] else
    if x == -1 then Nothing else Just $ concat ["#", element', " <= ", show x]


-- -----------------------------------------------------------------------------
-- Generate code for logical expressions

genPExp :: GenEnv -> GenCtx -> PExp -> Concat
genPExp    genEnv    ctx       x     = genPExp' genEnv ctx $ adjustPExp ctx x

genPExp' :: GenEnv -> GenCtx -> PExp                       -> Concat
genPExp'    genEnv    ctx       (PExp iType' pid' pos exp') = case exp' of
  IDeclPExp q d pexp -> Concat (IrPExp pid') $
    [ CString $ genQuant q, CString " "
    , cintercalate (CString ", ") $ map ((genDecl genEnv ctx)) d
    , CString $ optBar d, genPExp' genEnv ctx pexp]
    where
    optBar [] = ""
    optBar _  = " | "
  IClaferId _ "ref" _  (Just bind) -> CString $ "@ref" ++ timeJoin
    where
    boundIClafer = SMap.lookup bind (uidIClaferMap genEnv)
    timeJoin = case boundIClafer of
      Just c -> case (_mutable c, time ctx) of
        (True, Just t) -> "." ++ t
        _ -> ""
      _ -> ""
  IClaferId _ sid _ (Just bind) -> CString $
      if head sid == '~'
      then sid
      else if isNothing iType'
           then sid'
           else case fromJust $ iType' of
                  TInteger -> vsident
                  TReal -> vsident
                  TString -> vsident
                  _ -> sid'
    where
    boundIClafer = SMap.lookup bind (uidIClaferMap genEnv)
    {-sid' = (if istop then "" else '@' : genRelName "") ++ sid ++ timeJoin-}
    sid' = ('@' : genRelName "") ++ sid ++ timeJoin
    timeJoin = if sid == "this" then "" else case (boundIClafer, time ctx) of
      (Just IClafer {_mutable=True}, Just t) -> "." ++ t
      _ -> ""
    -- 29/March/2012  Rafael Olaechea: ref is now prepended with clafer name to be able to refer to it from partial instances.
    -- 30/March/2012 Rafael Olaechea added referredClaferUniqeuid to fix problems when having this.x > number  (e.g test/positive/i10.cfr )
    vsident = if (noalloyruncommand $ claferargs genEnv)
              then sid' ++  ".@"  ++ referredClaferUniqeuid ++ "_ref"
              else  sid'  ++ ".@ref"
      where
        referredClaferUniqeuid = if sid == "this" then topPath else sid
        topPath = case resPath ctx of
                    x:_ -> x
                    [] -> error "'AlloyLtl.genPExp': resPath is empty"
  IFunExp _ _ -> case exp'' of
    IFunExp _ _ -> genIFunExp genEnv pid' ctx exp''
    _ -> genPExp' genEnv ctx $ PExp iType' pid' pos exp''
    where
    exp'' = transformExp exp'
  IInt n -> CString $ show n
  IDouble _ -> error "AlloyLtl.genPExp': No real numbers allowed"
  IStr _ -> error "AlloyLtl.genPExp': No strings allowed"
  x -> error $ "AlloyLtl.genPExp': No pattern match for " ++ show x


-- 3-May-2012 Rafael Olaechea.
-- Removed transfromation from x = -2 to x = (0-2) as this creates problem with  partial instances.
-- See http://gsd.uwaterloo.ca:8888/question/461/new-translation-of-negative-number-x-into-0-x-is.
transformExp :: IExp -> IExp
transformExp (IFunExp op' (e1:_))
  | op' == iMin = IFunExp iMul [PExp (_iType e1) "" noSpan $ IInt (-1), e1]
transformExp    x@(IFunExp op' exps'@(e1:e2:_))
  | op' == iXor = IFunExp iNot [PExp (Just TBoolean) "" noSpan (IFunExp iIff exps')]
  | op' == iJoin && isClaferName' e1 && isClaferName' e2 &&
    getClaferName e1 == thisIdent && head (getClaferName e2) == '~' =
        IFunExp op' [e1{_iType = Just $ TClafer []}, e2]
  | otherwise  = x
transformExp x = x

genIFunExp :: GenEnv -> String -> GenCtx -> IExp             -> Concat
genIFunExp    genEnv    pid'      ctx       (IFunExp op' exps') =
  if (op' `elem` ltlOps)
  then Concat (IrPExp pid') $ surroundPar $ genLtlExp genEnv ctx op' exps'
  else if (op' == iSumSet)
    then genIFunExp genEnv pid' ctx (IFunExp iSumSet' [removeright firstExp, getRight firstExp])
    else if (op' == iSumSet')
      then Concat (IrPExp pid') $ intl exps'' (map CString $ genOp (Alloy42 `elem` (mode $ claferargs genEnv)) iSumSet)
      else Concat (IrPExp pid') $ intl exps'' (map CString $ genOp (Alloy42 `elem` (mode $ claferargs genEnv)) op')
  where
  firstExp = case exps' of
                    x:_ -> x
                    [] -> error "genIFunExp"
  surroundPar [] = []
  surroundPar xs = CString "(" : (xs ++ [CString ")"])
  intl
    | op' == iSumSet' = flip $ interleave
    | op' `elem` arithBinOps && length exps' == 2 = interleave
    | otherwise = \xs ys -> reverse $ interleave (reverse xs) (reverse ys)
  exps'' = map (optBrArg genEnv ctx) exps'
genIFunExp _ _ _ _ = error "Function genIFunExp from Alloy Generator expected a IFunExp as an argument but was given something else" --This should never happen

genLtlExp :: GenEnv -> GenCtx -> String -> [PExp] -> [Concat]
genLtlExp    genEnv    ctx       op'        exps' = {- trace ("call in genLtlExp; exps:\n" ++ show exps') $ -} dispatcher exps'
  where
  dispatcher
    | op' == iF = genF
    | op' == iX = genX
    | op' == iG = genG
    | op' == iU = genU
    | otherwise = (\_ -> [])
  genF [e1]
    | containsMutable genEnv e1 = mapToCStr ["some ", nextT, ":", currT, ".*", nextNLoop, " | "] ++ [genPExp' genEnv (ctx {time = Just nextT}) e1]
    | otherwise = [genPExp' genEnv (ctx {time = Just nextT}) e1]
  genX [e1]
    | containsMutable genEnv e1 = mapToCStr ["let ", nextT, "=", currT, ".", nextNLoop, " | some ", nextT, " and "] ++ [genPExp' genEnv (ctx {time = Just nextT}) e1]
    | otherwise = [genPExp' genEnv (ctx {time = Just nextT}) e1]
  genG [e1]
    | containsMutable genEnv e1 = mapToCStr ["some loop and all ", nextT, ":", currT, ".*", nextNLoop, " | "] ++ [genPExp' genEnv (ctx {time = Just nextT}) e1]
    | otherwise = [genPExp' genEnv (ctx {time = Just nextT}) e1]
  genU (e1:e2:_) = mapToCStr ["some ", nextT, ":", currT, ".*", nextNLoop, " | "] ++ [genPExp' genEnv (ctx {time = Just nextT}) e2] ++
    mapToCStr [" and ( all ", nextT', ":", currT, ".*", nextNLoop, " & ^", nextNLoop, ".", nextT, "|"] ++ [genPExp' genEnv (ctx {time = Just nextT'}) e1, CString ")"]
  nextNLoop = "(" ++ timeSig ++ " <: next + loop)"
  currT = maybe "t" id $ time ctx
  nextT = currT ++ "'"
  nextT' = nextT ++ "'"


containsMutable :: GenEnv -> PExp -> Bool
containsMutable    genEnv    (PExp _ _ _ exp') = case exp' of
  (IFunExp _ exps') -> bOrFoldl1 $ map (containsMutable genEnv) exps'
  (IClaferId _ _ _ (Just bind)) -> let
      boundIClafer = fromJust $ SMap.lookup bind (uidIClaferMap genEnv)
    in
      _mutable boundIClafer
  (IDeclPExp _ decls' e) -> bOrFoldl1 (map (containsMut genEnv) decls') || containsMutable genEnv e
  _ -> False
  where
  containsMut genEnv' (IDecl _ _ body') = containsMutable genEnv' body'


optBrArg :: GenEnv  -> GenCtx -> PExp -> Concat
optBrArg    genEnv     ctx       x     = brFun (genPExp' genEnv ctx) x
  where
  brFun = case x of
    PExp _ _ _ (IClaferId _ _ _ _) -> ($)
    PExp _ _ _ (IInt _) -> ($)
    _  -> brArg

interleave :: [Concat] -> [Concat] -> [Concat]
interleave [] [] = []
interleave (x:xs) [] = x:xs
interleave [] (x:xs) = x:xs
interleave (x:xs) ys = x : interleave ys xs

brArg :: (a -> Concat) -> a -> Concat
brArg f arg = cconcat [CString "(", f arg, CString ")"]

--     isAlloy42
genOp :: Bool -> String -> [String]
genOp    True       op'
  | op' == iPlus = [".plus[", "]"]
  | op' == iSub  = [".minus[", "]"]
  | otherwise   = genOp False op'
genOp    _             op'
  | op' == iSumSet = ["sum temp : "," | temp."]
  | op' `elem` unOps  = [op']
  | op' == iPlus = [".add[", "]"]
  | op' == iSub  = [".sub[", "]"]
  | op' == iMul = [".mul[", "]"]
  | op' == iDiv = [".div[", "]"]
  | op' `elem` logBinOps ++ relBinOps ++ arithBinOps = [" " ++ op' ++ " "]
  | op' == iUnion = [" + "]
  | op' == iDifference = [" - "]
  | op' == iIntersection = [" & "]
  | op' == iDomain = [" <: "]
  | op' == iRange = [" :> "]
  | op' == iJoin = ["."]
  | op' == iIfThenElse = [" => ", " else "]
genOp _ _ = error "This should never happen"

-- adjust parent
adjustPExp :: GenCtx -> PExp -> PExp
adjustPExp ctx (PExp t pid' pos x) = PExp t pid' pos $ adjustIExp ctx x

adjustIExp :: GenCtx -> IExp -> IExp
adjustIExp ctx x = case x of
  IDeclPExp q d pexp -> IDeclPExp q d $ adjustPExp ctx pexp
  IFunExp op' exps' -> adjNav $ IFunExp op' $ map adjExps exps'
    where
    (adjNav, adjExps) = if op' == iJoin then (aNav, id)
                        else (id, adjustPExp ctx)
  IClaferId _ _ _  _-> aNav x
  _  -> x
  where
  aNav = fst.(adjustNav $ resPath ctx)

adjustNav :: [String] -> IExp -> (IExp, [String])
adjustNav resPath' x@(IFunExp op' (pexp0:pexp:_))
  | op' == iJoin = (IFunExp iJoin
                   [pexp0{_exp = iexp0},
                    pexp{_exp = iexp}], path')
  | otherwise   = (x, resPath')
  where
  (iexp0, path) = adjustNav resPath' (_exp pexp0)
  (iexp, path') = adjustNav path    (_exp pexp)
adjustNav resPath' x@(IClaferId _ id' _ _)
  | id' == parentIdent = (x{_sident = "~@" ++ (genRelName topPath)}, tail resPath')
  | otherwise    = (x, resPath')
    where
      topPath = case resPath' of
                     r:_ -> r
                     [] -> error "AlloyLtl.adjustNav: resPath is empty"
adjustNav _ _ = error "Function adjustNav Expect a IFunExp or IClaferID as one of it's argument but it was given a differnt IExp" --This should never happen

genQuant :: IQuant -> String
genQuant    x       = case x of
  INo   -> "no"
  ILone -> "lone"
  IOne  -> "one"
  ISome -> "some"
  IAll -> "all"


genDecl :: GenEnv -> GenCtx -> IDecl -> Concat
genDecl    genEnv    ctx       x      = case x of
  IDecl disj locids pexp -> cconcat [CString $ genDisj disj, CString " ",
    CString $ intercalate ", " locids, CString " : ", genPExp genEnv ctx pexp]


genDisj :: Bool -> String
genDisj    x     = case x of
  False -> ""
  True  -> "disj"

-- mapping line/columns between Clafer and Alloy code

data AlloyEnv = AlloyEnv {
  lineCol :: (LineNo, ColNo),
  mapping :: [(Span, IrTrace)]
  } deriving (Eq,Show)

mapLineCol :: Concat -> [(Span, IrTrace)]
mapLineCol code = mapping $ execState (mapLineCol' code) (AlloyEnv (firstLine, firstCol) [])

addCode :: MonadState AlloyEnv m => String -> m ()
addCode str = modify (\s -> s {lineCol = lineno (lineCol s) str})

mapLineCol' :: MonadState AlloyEnv m => Concat -> m ()
mapLineCol' (CString str) = addCode str
mapLineCol' c@(Concat srcPos' n) = do
  posStart <- gets lineCol
  _ <- mapM mapLineCol' n
  posEnd   <- gets lineCol

  {-
   - Alloy only counts inner parenthesis as part of the constraint, but not outer parenthesis.
   - ex1. the constraint looks like this in the file
   -    (constraint a) <=> (constraint b)
   - But the actual constraint in the API is
   -    constraint a) <=> (constraint b
   -
   - ex2. the constraint looks like this in the file
   -    (((#((this.@r_c2_Finger).@r_c3_Pinky)).add[(#((this.@r_c2_Finger).@r_c4_Index))]).add[(#((this.@r_c2_Finger).@r_c5_Middle))]) = 0
   - But the actual constraint in the API is
   -    #((this.@r_c2_Finger).@r_c3_Pinky)).add[(#((this.@r_c2_Finger).@r_c4_Index))]).add[(#((this.@r_c2_Finger).@r_c5_Middle))]) = 0
   -
   - Seems unintuitive since the brackets are now unbalanced but that's how they work in Alloy. The next
   - few lines of code is counting the beginning and ending parenthesis's and subtracting them from the
   - positions in the map file.
   - Same is true for square brackets.
   - This next little snippet is rather inefficient since we are retraversing the Concat's to flatten.
   - But it's the simplest and correct solution I can think of right now.
   -}
  let flat = flatten c
      raiseStart = countLeading "([" flat
      deductEnd = -(countTrailing ")]" flat)
  modify (\s -> s {mapping = (Span (uncurry Pos $ posStart `addColumn` raiseStart) (uncurry Pos $ posEnd `addColumn` deductEnd), srcPos') : (mapping s)})

addColumn :: Interval -> Integer -> Interval
addColumn (x, y) c = (x, y + c)
countLeading :: String -> String -> Integer
countLeading c xs = toInteger $ length $ takeWhile (`elem` c) xs
countTrailing :: String -> String -> Integer
countTrailing c xs = countLeading c (reverse xs)

lineno :: (Integer, ColNo) -> String -> (Integer, ColNo)
lineno (l, c) str = (l + newLines, (if newLines > 0 then firstCol else c) + newCol)
  where
  newLines = toInteger $ length $ filter (== '\n') str
  newCol   = toInteger $ length $ takeWhile (/= '\n') $ reverse str

firstCol :: ColNo
firstCol  = 1 :: ColNo
firstLine :: LineNo
firstLine = 1 :: LineNo

removeright :: PExp -> PExp
removeright (PExp _ _ _ (IFunExp _ (x : (PExp _ _ _ (IClaferId _ _ _ _)) : _))) = x
removeright (PExp t id' pos (IFunExp o (x1:x2:xs))) = (PExp t id' pos (IFunExp o (x1:(removeright x2):xs)))
removeright (PExp _ _ _ _) = error "Function removeright from the AlloyGenerator expects a PExp with a IFunExp inside, was given something else" --This should never happen

getRight :: PExp -> PExp
getRight (PExp _ _ _ (IFunExp _ (_:x:_))) = getRight x
getRight p = p

genTimeAllQuant :: String -> Concat
genTimeAllQuant tvar = CString $ "all " ++ tvar ++ " : " ++ timeSig ++ " | "
