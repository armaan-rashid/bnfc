-- File generated by the BNF Converter (bnfc 2.9.5).

{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
#if __GLASGOW_HASKELL__ <= 708
{-# LANGUAGE OverlappingInstances #-}
#endif

-- | Pretty-printer for PrintBNF.

module PrintBNF where

import Prelude
  ( ($), (.)
  , Bool(..), (==), (<)
  , Int, Integer, Double, (+), (-), (*)
  , String, (++)
  , ShowS, showChar, showString
  , all, elem, foldr, id, map, null, replicate, shows, span
  )
import Data.Char ( Char, isSpace )
import qualified AbsBNF

-- | The top-level printing method.

printTree :: Print a => a -> String
printTree = render . prt 0

type Doc = [ShowS] -> [ShowS]

doc :: ShowS -> Doc
doc = (:)

render :: Doc -> String
render d = rend 0 False (map ($ "") $ d []) ""
  where
  rend
    :: Int        -- ^ Indentation level.
    -> Bool       -- ^ Pending indentation to be output before next character?
    -> [String]
    -> ShowS
  rend i p = \case
      "["      :ts -> char '[' . rend i False ts
      "("      :ts -> char '(' . rend i False ts
      "{"      :ts -> onNewLine i     p . showChar   '{'  . new (i+1) ts
      "}" : ";":ts -> onNewLine (i-1) p . showString "};" . new (i-1) ts
      "}"      :ts -> onNewLine (i-1) p . showChar   '}'  . new (i-1) ts
      [";"]        -> char ';'
      ";"      :ts -> char ';' . new i ts
      t  : ts@(s:_) | closingOrPunctuation s
                   -> pending . showString t . rend i False ts
      t        :ts -> pending . space t      . rend i False ts
      []           -> id
    where
    -- Output character after pending indentation.
    char :: Char -> ShowS
    char c = pending . showChar c

    -- Output pending indentation.
    pending :: ShowS
    pending = if p then indent i else id

  -- Indentation (spaces) for given indentation level.
  indent :: Int -> ShowS
  indent i = replicateS (2*i) (showChar ' ')

  -- Continue rendering in new line with new indentation.
  new :: Int -> [String] -> ShowS
  new j ts = showChar '\n' . rend j True ts

  -- Make sure we are on a fresh line.
  onNewLine :: Int -> Bool -> ShowS
  onNewLine i p = (if p then id else showChar '\n') . indent i

  -- Separate given string from following text by a space (if needed).
  space :: String -> ShowS
  space t s =
    case (all isSpace t, null spc, null rest) of
      (True , _   , True ) -> []             -- remove trailing space
      (False, _   , True ) -> t              -- remove trailing space
      (False, True, False) -> t ++ ' ' : s   -- add space if none
      _                    -> t ++ s
    where
      (spc, rest) = span isSpace s

  closingOrPunctuation :: String -> Bool
  closingOrPunctuation [c] = c `elem` closerOrPunct
  closingOrPunctuation _   = False

  closerOrPunct :: String
  closerOrPunct = ")],;"

parenth :: Doc -> Doc
parenth ss = doc (showChar '(') . ss . doc (showChar ')')

concatS :: [ShowS] -> ShowS
concatS = foldr (.) id

concatD :: [Doc] -> Doc
concatD = foldr (.) id

replicateS :: Int -> ShowS -> ShowS
replicateS n f = concatS (replicate n f)

-- | The printer class does the job.

class Print a where
  prt :: Int -> a -> Doc

instance {-# OVERLAPPABLE #-} Print a => Print [a] where
  prt i = concatD . map (prt i)

instance Print Char where
  prt _ c = doc (showChar '\'' . mkEsc '\'' c . showChar '\'')

instance Print String where
  prt _ = printString

printString :: String -> Doc
printString s = doc (showChar '"' . concatS (map (mkEsc '"') s) . showChar '"')

mkEsc :: Char -> Char -> ShowS
mkEsc q = \case
  s | s == q -> showChar '\\' . showChar s
  '\\' -> showString "\\\\"
  '\n' -> showString "\\n"
  '\t' -> showString "\\t"
  s -> showChar s

prPrec :: Int -> Int -> Doc -> Doc
prPrec i j = if j < i then parenth else id

instance Print Integer where
  prt _ x = doc (shows x)

instance Print Double where
  prt _ x = doc (shows x)

instance Print AbsBNF.Ident where
  prt _ (AbsBNF.Ident i) = doc $ showString i
instance Print AbsBNF.LGrammar where
  prt i = \case
    AbsBNF.LGr ldefs -> prPrec i 0 (concatD [prt 0 ldefs])

instance Print AbsBNF.LDef where
  prt i = \case
    AbsBNF.DefAll def -> prPrec i 0 (concatD [prt 0 def])
    AbsBNF.DefSome ids def -> prPrec i 0 (concatD [prt 0 ids, doc (showString ":"), prt 0 def])
    AbsBNF.LDefView ids -> prPrec i 0 (concatD [doc (showString "views"), prt 0 ids])

instance Print [AbsBNF.LDef] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString ";"), prt 0 xs]

instance Print AbsBNF.Grammar where
  prt i = \case
    AbsBNF.Grammar defs -> prPrec i 0 (concatD [prt 0 defs])

instance Print [AbsBNF.Def] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString ";"), prt 0 xs]

instance Print [AbsBNF.Item] where
  prt _ [] = concatD []
  prt _ (x:xs) = concatD [prt 0 x, prt 0 xs]

instance Print AbsBNF.Def where
  prt i = \case
    AbsBNF.Rule label cat items -> prPrec i 0 (concatD [prt 0 label, doc (showString "."), prt 0 cat, doc (showString "::="), prt 0 items])
    AbsBNF.Comment str -> prPrec i 0 (concatD [doc (showString "comment"), printString str])
    AbsBNF.Comments str1 str2 -> prPrec i 0 (concatD [doc (showString "comment"), printString str1, printString str2])
    AbsBNF.Internal label cat items -> prPrec i 0 (concatD [doc (showString "internal"), prt 0 label, doc (showString "."), prt 0 cat, doc (showString "::="), prt 0 items])
    AbsBNF.Token id_ reg -> prPrec i 0 (concatD [doc (showString "token"), prt 0 id_, prt 0 reg])
    AbsBNF.PosToken id_ reg -> prPrec i 0 (concatD [doc (showString "position"), doc (showString "token"), prt 0 id_, prt 0 reg])
    AbsBNF.Entryp ids -> prPrec i 0 (concatD [doc (showString "entrypoints"), prt 0 ids])
    AbsBNF.Separator minimumsize cat str -> prPrec i 0 (concatD [doc (showString "separator"), prt 0 minimumsize, prt 0 cat, printString str])
    AbsBNF.Terminator minimumsize cat str -> prPrec i 0 (concatD [doc (showString "terminator"), prt 0 minimumsize, prt 0 cat, printString str])
    AbsBNF.Delimiters cat str1 str2 separation minimumsize -> prPrec i 0 (concatD [doc (showString "delimiters"), prt 0 cat, printString str1, printString str2, prt 0 separation, prt 0 minimumsize])
    AbsBNF.Coercions id_ n -> prPrec i 0 (concatD [doc (showString "coercions"), prt 0 id_, prt 0 n])
    AbsBNF.Rules id_ rhss -> prPrec i 0 (concatD [doc (showString "rules"), prt 0 id_, doc (showString "::="), prt 0 rhss])
    AbsBNF.Function id_ args exp -> prPrec i 0 (concatD [doc (showString "define"), prt 0 id_, prt 0 args, doc (showString "="), prt 0 exp])
    AbsBNF.Layout strs -> prPrec i 0 (concatD [doc (showString "layout"), prt 0 strs])
    AbsBNF.LayoutStop strs -> prPrec i 0 (concatD [doc (showString "layout"), doc (showString "stop"), prt 0 strs])
    AbsBNF.LayoutTop -> prPrec i 0 (concatD [doc (showString "layout"), doc (showString "toplevel")])

instance Print AbsBNF.Item where
  prt i = \case
    AbsBNF.Terminal str -> prPrec i 0 (concatD [printString str])
    AbsBNF.NTerminal cat -> prPrec i 0 (concatD [prt 0 cat])

instance Print AbsBNF.Cat where
  prt i = \case
    AbsBNF.ListCat cat -> prPrec i 0 (concatD [doc (showString "["), prt 0 cat, doc (showString "]")])
    AbsBNF.IdCat id_ -> prPrec i 0 (concatD [prt 0 id_])

instance Print AbsBNF.Label where
  prt i = \case
    AbsBNF.LabNoP labelid -> prPrec i 0 (concatD [prt 0 labelid])
    AbsBNF.LabP labelid profitems -> prPrec i 0 (concatD [prt 0 labelid, prt 0 profitems])
    AbsBNF.LabPF labelid1 labelid2 profitems -> prPrec i 0 (concatD [prt 0 labelid1, prt 0 labelid2, prt 0 profitems])
    AbsBNF.LabF labelid1 labelid2 -> prPrec i 0 (concatD [prt 0 labelid1, prt 0 labelid2])

instance Print AbsBNF.LabelId where
  prt i = \case
    AbsBNF.Id id_ -> prPrec i 0 (concatD [prt 0 id_])
    AbsBNF.Wild -> prPrec i 0 (concatD [doc (showString "_")])
    AbsBNF.ListE -> prPrec i 0 (concatD [doc (showString "["), doc (showString "]")])
    AbsBNF.ListCons -> prPrec i 0 (concatD [doc (showString "("), doc (showString ":"), doc (showString ")")])
    AbsBNF.ListOne -> prPrec i 0 (concatD [doc (showString "("), doc (showString ":"), doc (showString "["), doc (showString "]"), doc (showString ")")])

instance Print AbsBNF.ProfItem where
  prt i = \case
    AbsBNF.ProfIt intlists ns -> prPrec i 0 (concatD [doc (showString "("), doc (showString "["), prt 0 intlists, doc (showString "]"), doc (showString ","), doc (showString "["), prt 0 ns, doc (showString "]"), doc (showString ")")])

instance Print AbsBNF.IntList where
  prt i = \case
    AbsBNF.Ints ns -> prPrec i 0 (concatD [doc (showString "["), prt 0 ns, doc (showString "]")])

instance Print [Integer] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString ","), prt 0 xs]

instance Print [AbsBNF.IntList] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString ","), prt 0 xs]

instance Print [AbsBNF.ProfItem] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, prt 0 xs]

instance Print AbsBNF.Separation where
  prt i = \case
    AbsBNF.SepNone -> prPrec i 0 (concatD [])
    AbsBNF.SepTerm str -> prPrec i 0 (concatD [doc (showString "terminator"), printString str])
    AbsBNF.SepSepar str -> prPrec i 0 (concatD [doc (showString "separator"), printString str])

instance Print AbsBNF.Arg where
  prt i = \case
    AbsBNF.Arg id_ -> prPrec i 0 (concatD [prt 0 id_])

instance Print [AbsBNF.Arg] where
  prt _ [] = concatD []
  prt _ (x:xs) = concatD [prt 0 x, prt 0 xs]

instance Print AbsBNF.Exp where
  prt i = \case
    AbsBNF.Cons exp1 exp2 -> prPrec i 0 (concatD [prt 1 exp1, doc (showString ":"), prt 0 exp2])
    AbsBNF.App id_ exps -> prPrec i 1 (concatD [prt 0 id_, prt 2 exps])
    AbsBNF.Var id_ -> prPrec i 2 (concatD [prt 0 id_])
    AbsBNF.LitInt n -> prPrec i 2 (concatD [prt 0 n])
    AbsBNF.LitChar c -> prPrec i 2 (concatD [prt 0 c])
    AbsBNF.LitString str -> prPrec i 2 (concatD [printString str])
    AbsBNF.LitDouble d -> prPrec i 2 (concatD [prt 0 d])
    AbsBNF.List exps -> prPrec i 2 (concatD [doc (showString "["), prt 0 exps, doc (showString "]")])

instance Print [AbsBNF.Exp] where
  prt 2 [x] = concatD [prt 2 x]
  prt 2 (x:xs) = concatD [prt 2 x, prt 2 xs]
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString ","), prt 0 xs]

instance Print [String] where
  prt _ [] = concatD []
  prt _ [x] = concatD [printString x]
  prt _ (x:xs) = concatD [printString x, doc (showString ","), prt 0 xs]

instance Print [AbsBNF.RHS] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString "|"), prt 0 xs]

instance Print AbsBNF.RHS where
  prt i = \case
    AbsBNF.RHS items -> prPrec i 0 (concatD [prt 0 items])

instance Print AbsBNF.MinimumSize where
  prt i = \case
    AbsBNF.MNonempty -> prPrec i 0 (concatD [doc (showString "nonempty")])
    AbsBNF.MEmpty -> prPrec i 0 (concatD [])

instance Print AbsBNF.Reg where
  prt i = \case
    AbsBNF.RSeq reg1 reg2 -> prPrec i 2 (concatD [prt 2 reg1, prt 3 reg2])
    AbsBNF.RAlt reg1 reg2 -> prPrec i 1 (concatD [prt 1 reg1, doc (showString "|"), prt 2 reg2])
    AbsBNF.RMinus reg1 reg2 -> prPrec i 1 (concatD [prt 2 reg1, doc (showString "-"), prt 2 reg2])
    AbsBNF.RStar reg -> prPrec i 3 (concatD [prt 3 reg, doc (showString "*")])
    AbsBNF.RPlus reg -> prPrec i 3 (concatD [prt 3 reg, doc (showString "+")])
    AbsBNF.ROpt reg -> prPrec i 3 (concatD [prt 3 reg, doc (showString "?")])
    AbsBNF.REps -> prPrec i 3 (concatD [doc (showString "eps")])
    AbsBNF.RChar c -> prPrec i 3 (concatD [prt 0 c])
    AbsBNF.RAlts str -> prPrec i 3 (concatD [doc (showString "["), printString str, doc (showString "]")])
    AbsBNF.RSeqs str -> prPrec i 3 (concatD [doc (showString "{"), printString str, doc (showString "}")])
    AbsBNF.RDigit -> prPrec i 3 (concatD [doc (showString "digit")])
    AbsBNF.RLetter -> prPrec i 3 (concatD [doc (showString "letter")])
    AbsBNF.RUpper -> prPrec i 3 (concatD [doc (showString "upper")])
    AbsBNF.RLower -> prPrec i 3 (concatD [doc (showString "lower")])
    AbsBNF.RAny -> prPrec i 3 (concatD [doc (showString "char")])

instance Print [AbsBNF.Ident] where
  prt _ [] = concatD []
  prt _ [x] = concatD [prt 0 x]
  prt _ (x:xs) = concatD [prt 0 x, doc (showString ","), prt 0 xs]
