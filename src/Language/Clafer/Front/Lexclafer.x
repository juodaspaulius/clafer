-- -*- haskell -*-
-- This Alex file was machine-generated by the BNF converter
{
{-# OPTIONS -fno-warn-incomplete-patterns #-}
{-# OPTIONS_GHC -w #-}
module Language.Clafer.Front.Lexclafer where



import qualified Data.Bits
import Data.Word (Word8)
}


$l = [a-zA-Z\192 - \255] # [\215 \247]    -- isolatin1 letter FIXME
$c = [A-Z\192-\221] # [\215]    -- capital isolatin1 letter FIXME
$s = [a-z\222-\255] # [\247]    -- small isolatin1 letter FIXME
$d = [0-9]                -- digit
$i = [$l $d _ ']          -- identifier character
$u = [\0-\255]          -- universal: any character

@rsyms =    -- symbols and non-identifier-like reserved words
   \= | \[ | \] | \< \< | \> \> | \{ | \} | \` | \: | \- \> | \- \> \> | \: \= | \? | \+ | \* | \. \. | \| | \< \= \> | \= \> | \| \| | \& \& | \! | \< | \> | \< \= | \> \= | \! \= | \- | \/ | \# | \+ \+ | \, | \- \- | \* \* | \< \: | \: \> | \. | \; | \\ | \( | \)

:-
"//" [.]* ; -- Toss single line comments
"/*" ([$u # \*] | \* [$u # \/])* ("*")+ "/" ; 

$white+ ;
@rsyms { tok (\p s -> PT p (eitherResIdent (TV . share) s)) }
$d + { tok (\p s -> PT p (eitherResIdent (T_PosInteger . share) s)) }
$d + \. $d + (e \- ? $d +)? { tok (\p s -> PT p (eitherResIdent (T_PosDouble . share) s)) }
\" ($u # [\" \\]| \\ [\" \\ n t]) * \" { tok (\p s -> PT p (eitherResIdent (T_PosString . share) s)) }
$l ($l | $d | \_ | \')* { tok (\p s -> PT p (eitherResIdent (T_PosIdent . share) s)) }

$l $i*   { tok (\p s -> PT p (eitherResIdent (TV . share) s)) }





{

tok f p s = f p s

share :: String -> String
share = id

data Tok =
   TS !String !Int    -- reserved words and symbols
 | TL !String         -- string literals
 | TI !String         -- integer literals
 | TV !String         -- identifiers
 | TD !String         -- double precision float literals
 | TC !String         -- character literals
 | T_PosInteger !String
 | T_PosDouble !String
 | T_PosString !String
 | T_PosIdent !String

 deriving (Eq,Show,Ord)

data Token = 
   PT  Posn Tok
 | Err Posn
  deriving (Eq,Show,Ord)

tokenPos (PT (Pn _ l _) _ :_) = "line " ++ show l
tokenPos (Err (Pn _ l _) :_) = "line " ++ show l
tokenPos _ = "end of file"

tokenPosn (PT p _) = p
tokenPosn (Err p) = p
tokenLineCol = posLineCol . tokenPosn
posLineCol (Pn _ l c) = (l,c)
mkPosToken t@(PT p _) = (posLineCol p, prToken t)

prToken t = case t of
  PT _ (TS s _) -> s
  PT _ (TL s)   -> s
  PT _ (TI s)   -> s
  PT _ (TV s)   -> s
  PT _ (TD s)   -> s
  PT _ (TC s)   -> s
  PT _ (T_PosInteger s) -> s
  PT _ (T_PosDouble s) -> s
  PT _ (T_PosString s) -> s
  PT _ (T_PosIdent s) -> s


data BTree = N | B String Tok BTree BTree deriving (Show)

eitherResIdent :: (String -> Tok) -> String -> Tok
eitherResIdent tv s = treeFind resWords
  where
  treeFind N = tv s
  treeFind (B a t left right) | s < a  = treeFind left
                              | s > a  = treeFind right
                              | s == a = t

resWords = b ">>" 32 (b "." 16 (b "**" 8 (b "&&" 4 (b "!=" 2 (b "!" 1 N N) (b "#" 3 N N)) (b ")" 6 (b "(" 5 N N) (b "*" 7 N N))) (b "-" 12 (b "++" 10 (b "+" 9 N N) (b "," 11 N N)) (b "->" 14 (b "--" 13 N N) (b "->>" 15 N N)))) (b "<:" 24 (b ":=" 20 (b "/" 18 (b ".." 17 N N) (b ":" 19 N N)) (b ";" 22 (b ":>" 21 N N) (b "<" 23 N N))) (b "=" 28 (b "<=" 26 (b "<<" 25 N N) (b "<=>" 27 N N)) (b ">" 30 (b "=>" 29 N N) (b ">=" 31 N N))))) (b "min" 48 (b "assert" 40 (b "]" 36 (b "[" 34 (b "?" 33 N N) (b "\\" 35 N N)) (b "abstract" 38 (b "`" 37 N N) (b "all" 39 N N))) (b "if" 44 (b "else" 42 (b "disj" 41 N N) (b "enum" 43 N N)) (b "lone" 46 (b "in" 45 N N) (b "max" 47 N N)))) (b "sum" 56 (b "one" 52 (b "no" 50 (b "mux" 49 N N) (b "not" 51 N N)) (b "or" 54 (b "opt" 53 N N) (b "some" 55 N N))) (b "|" 60 (b "xor" 58 (b "then" 57 N N) (b "{" 59 N N)) (b "}" 62 (b "||" 61 N N) N))))
   where b s n = let bs = id s
                  in B bs (TS bs n)

unescapeInitTail :: String -> String
unescapeInitTail = id . unesc . tail . id where
  unesc s = case s of
    '\\':c:cs | elem c ['\"', '\\', '\''] -> c : unesc cs
    '\\':'n':cs  -> '\n' : unesc cs
    '\\':'t':cs  -> '\t' : unesc cs
    '"':[]    -> []
    c:cs      -> c : unesc cs
    _         -> []

-------------------------------------------------------------------
-- Alex wrapper code.
-- A modified "posn" wrapper.
-------------------------------------------------------------------

data Posn = Pn !Int !Int !Int
      deriving (Eq, Show,Ord)

alexStartPos :: Posn
alexStartPos = Pn 0 1 1

alexMove :: Posn -> Char -> Posn
alexMove (Pn a l c) '\t' = Pn (a+1)  l     (((c+7) `div` 8)*8+1)
alexMove (Pn a l c) '\n' = Pn (a+1) (l+1)   1
alexMove (Pn a l c) _    = Pn (a+1)  l     (c+1)

type Byte = Word8

type AlexInput = (Posn,     -- current position,
                  Char,     -- previous char
                  [Byte],   -- pending bytes on the current char
                  String)   -- current input string

tokens :: String -> [Token]
tokens str = go (alexStartPos, '\n', [], str)
    where
      go :: AlexInput -> [Token]
      go inp@(pos, _, _, str) =
               case alexScan inp 0 of
                AlexEOF                   -> []
                AlexError (pos, _, _, _)  -> [Err pos]
                AlexSkip  inp' len        -> go inp'
                AlexToken inp' len act    -> act pos (take len str) : (go inp')

alexGetByte :: AlexInput -> Maybe (Byte,AlexInput)
alexGetByte (p, c, (b:bs), s) = Just (b, (p, c, bs, s))
alexGetByte (p, _, [], s) =
  case  s of
    []  -> Nothing
    (c:s) ->
             let p'     = alexMove p c
                 (b:bs) = utf8Encode c
              in p' `seq` Just (b, (p', c, bs, s))

alexInputPrevChar :: AlexInput -> Char
alexInputPrevChar (p, c, bs, s) = c

  -- | Encode a Haskell String to a list of Word8 values, in UTF8 format.
utf8Encode :: Char -> [Word8]
utf8Encode = map fromIntegral . go . ord
 where
  go oc
   | oc <= 0x7f       = [oc]

   | oc <= 0x7ff      = [ 0xc0 + (oc `Data.Bits.shiftR` 6)
                        , 0x80 + oc Data.Bits..&. 0x3f
                        ]

   | oc <= 0xffff     = [ 0xe0 + (oc `Data.Bits.shiftR` 12)
                        , 0x80 + ((oc `Data.Bits.shiftR` 6) Data.Bits..&. 0x3f)
                        , 0x80 + oc Data.Bits..&. 0x3f
                        ]
   | otherwise        = [ 0xf0 + (oc `Data.Bits.shiftR` 18)
                        , 0x80 + ((oc `Data.Bits.shiftR` 12) Data.Bits..&. 0x3f)
                        , 0x80 + ((oc `Data.Bits.shiftR` 6) Data.Bits..&. 0x3f)
                        , 0x80 + oc Data.Bits..&. 0x3f
                        ]
}
