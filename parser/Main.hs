module Main where

import Control.Applicative
import Data.Char


-- tipe data baru untuk Json Object
data JsonValue
  = JsonNull
  | JsonBool Bool
  | JsonNumber Integer
  | JsonString String
  | JsonArray [JsonValue]
  | JsonObject [(String, JsonValue)]
  deriving (Show, Eq)


-- Tipe data (general) dari fungsi parser lainnya
newtype Parser a = Parser {runParser :: String -> Maybe (String, a)}


-- agar Parser memenuhi syarat Functor maka perlu
-- implementasi fungsi fmap
-- (a -> b) -> (String -> Maybe (String, a)) -> (String -> Maybe (String, b))
instance Functor Parser where
  fmap f (Parser p) =
    Parser $ \input -> do -- Take a String named input
      (input', x) <- p input -- Extracting Parser input
      Just (input', f x) -- Applying f to x and return it


instance Applicative Parser where
  pure x      = Parser $ \input -> Just (input, x)
  (Parser p1) <*> (Parser p2)  = Parser $ \input -> do
    (input', f) <- p1 input -- extracting function from p1
    (input'', a) <- p2 input'
    Just (input'', f a) -- applying f to a


instance Alternative Parser where
  empty = Parser $ const Nothing
  (Parser p1) <|> (Parser p2) =
    Parser $ \input -> p1 input <|> p2 input


-- charParser :: Char -> Parser Char
-- charParser x = Parser $ \input ->
--   case input of
--     y : ys | x == y -> Just (ys, x)
--     _ -> Nothing
charParser :: Char -> Parser Char
charParser x = Parser f
  where
    f (y:ys)
      | x == y = Just (ys, x)
      | otherwise = Nothing
    f [] = Nothing


-- Karena sequenceA hanya dapat digunakan pada tipe
-- dengan Traversable dan Applicative, maka perlu
-- membuktikan Parser memenuhi keduanya
stringParser :: String -> Parser String
stringParser = sequenceA . map charParser


-- check if a Parser return something or not
-- if not, then return Nothing
notNull :: Parser [a] -> Parser [a]
notNull (Parser p) =
  Parser $ \input -> do
    (input', xs) <- p input
    if null xs
      then Nothing
      else Just (input', xs)


jsonNull :: Parser JsonValue
jsonNull = fmap (const JsonNull) (stringParser "null")


jsonBool :: Parser JsonValue
jsonBool = f <$> (stringParser "true" <|> stringParser "false")
  where f "true"  = JsonBool True
        f "false" = JsonBool False
        f _       = undefined


-- span equivalent for Parser
spanParser :: (Char -> Bool) -> Parser String
spanParser f =
  Parser $ \input ->
    let (token, rest) = span f input  -- the token as long as the f True
      in Just (rest, token)  -- return to Maybe(String, String)


jsonNumber :: Parser JsonValue
jsonNumber = f <$> notNull (spanParser isDigit)  -- spanParser isDigit still return Parser String
  where f ds = JsonNumber $ read ds  -- convert the String to JsonNumber


stringLiteral :: Parser String
stringLiteral = charParser '"' *> spanParser (/= '"') <* charParser '"'


jsonString :: Parser JsonValue
jsonString = JsonString <$> stringLiteral


ws :: Parser String
ws = spanParser isSpace


splitBy :: Parser a -> Parser b -> Parser [b]
splitBy sep element = (:) <$> element <*> many (sep *> element) <|> pure []


elements :: Parser [JsonValue]
elements = splitBy (ws *> charParser ',' <* ws) jsonValue


jsonArray :: Parser JsonValue
jsonArray = JsonArray <$> (charParser '[' *> ws *> elements <* ws <* charParser ']')


pairs :: Parser [(String, JsonValue)]
pairs = splitBy (ws *> charParser ',' <* ws) pair
  where pair = (\key _ value -> (key, value)) <$> stringLiteral <*> (ws *> charParser ':' <* ws) <*> jsonValue


jsonObject :: Parser JsonValue
jsonObject = JsonObject <$> (charParser '{' *> ws *> pairs <* ws <* charParser '}')


jsonValue :: Parser JsonValue
jsonValue = jsonNull <|> jsonBool <|> jsonNumber <|> jsonString <|> jsonArray <|> jsonObject


parseFile :: FilePath -> Parser a -> IO (Maybe a)
parseFile fileName parser = do
  input <- readFile fileName
  return (snd <$> runParser parser input)


showValue :: Show a => Maybe a -> IO ()
showValue (Just x) = print x
showValue n        = print n


main :: IO (Maybe JsonValue)
main = do
  putStr "Masukkan nama file : "
  input <- getLine
  parseFile input jsonValue