{-# OPTIONS_GHC -Wno-incomplete-patterns #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Use <$>" #-}
{-# HLINT ignore "Use when" #-}
{-# HLINT ignore "Redundant bracket" #-}
module Servicos.Sessao.SessaoController where

import Control.Concurrent (threadDelay)
import Data.Aeson (FromJSON, ToJSON, decode, encode)
import Data.Bool (Bool)
import qualified Data.ByteString.Lazy  as B
import Data.List (delete)
import Data.Maybe
import Data.String (String)
import qualified Modelos.Administrador
import Modelos.Filme (Filme (Filme, duracao, ident, titulo))
import Modelos.Sessao
    ( Sessao(idSala, filme, ident, horario, Sessao), Sessao(horario) )
import System.Directory
import Modelos.Compra


constantePATH :: String
constantePATH = "./BancoDeDados/Sessao.json"

constanteTempPATH :: String
constanteTempPATH = "./BancoDeDados/SessaoTemp.json"

-- Retorna uma lista com todas as sessoes cadastradas
getSessoesJSON :: IO [Sessao]
getSessoesJSON = do
  file <- B.readFile constantePATH
  let decodedFile = decode file :: Maybe [Sessao]
  case decodedFile of
    Nothing -> pure []
    Just out -> pure out

-- Recebe um IO[Sessao] e uma sessao e retorna uma nova lista adicionando as duas
retornaLista :: IO [Sessao] -> Sessao -> IO [Sessao]
retornaLista acaoLista sessao = do
  lista <- acaoLista
  return (lista ++ [mudaId (length lista + 1) sessao])

-- Muda o id de umma sessao de acordo com a quantidade de sessoes
mudaId :: Int -> Sessao -> Sessao
mudaId newIdent sessao = sessao {Modelos.Sessao.ident = newIdent}

-- Adiciona uma sessao ao arquivo JSON
adicionaSessaoJSON :: Sessao -> IO ()
adicionaSessaoJSON sessao = do
  let conteudo = getSessoesJSON
  listaSessoes <- retornaLista conteudo sessao

  B.writeFile constanteTempPATH $ encode listaSessoes
  removeFile constantePATH
  renameFile constanteTempPATH constantePATH

-- A regra para registrar duas sessoes na mesma sala é que outra sessao só pode ser cadastrada
-- uma hora após um filme acabar
validaSessaoSala :: Sessao -> Sessao -> Bool
validaSessaoSala novaSessao sessaoExistente =
  idSala novaSessao == idSala sessaoExistente
    && (comparaHorarioSessao (horario novaSessao) (horario sessaoExistente) || verificaFilmeTerminou novaSessao sessaoExistente)

-- Função para comparar o horário das sessões
comparaHorarioSessao :: (Int, Int) -> (Int, Int) -> Bool
comparaHorarioSessao (hora1, minuto1) (hora2, minuto2) = hora1 == hora2

-- Verifica se o horario  esta no formato correto, hora >=0 e <=23 e minuto >=0 e <=59
validaHorario :: (Int, Int) -> Bool
validaHorario (hora, minuto) = (hora >= 0 && hora <= 23) && (minuto >= 0 && minuto <= 59)

verificaFilmeTerminou :: Sessao -> Sessao -> Bool
verificaFilmeTerminou novaSessao sessaoExistente =
  let duracaoFilmeSessaoExistente = read (duracao (filme sessaoExistente)) :: Int
      duracaoFilmeSessaoNova = read (duracao (filme novaSessao)) :: Int
      (horasSessaoExistente, minutosSessaoExistente) = horario sessaoExistente
      (horasSessaoNova, minutosSessaoNova) = horario novaSessao
      totalMinutosExistentes = horasSessaoExistente * 60 + duracaoFilmeSessaoExistente + minutosSessaoExistente
      totalMinutosNova = horasSessaoNova * 60 + duracaoFilmeSessaoNova + minutosSessaoNova
      totalMinutosSessaoNova = horasSessaoNova * 60 + minutosSessaoNova
      totalMinutosSessaoExistente = horasSessaoExistente * 60 + minutosSessaoExistente
   in if horasSessaoNova < horasSessaoExistente
        then totalMinutosSessaoExistente - totalMinutosNova < 60
        else totalMinutosSessaoNova - totalMinutosExistentes < 60

-- Deleta uma sessao do arquivo JSON a partir do identificador
deletaSessao :: Int -> IO ()
deletaSessao identificador = do
  sessoes <- getSessoesJSON
  let novaLista = deleteSessaoPorIdentificador identificador sessoes
  if length novaLista /= length sessoes
    then do
      B.writeFile constanteTempPATH $ encode novaLista
      removeFile constantePATH
      renameFile constanteTempPATH constantePATH
      putStrLn "Sessão deletada com sucesso!"
      threadDelay 1200000
    else do
      putStrLn "Não foi encontrada uma sessão com o identificador fornecido."
      threadDelay 1200000

-- Remove uma sessao da lista com base no identificador
deleteSessaoPorIdentificador :: Int -> [Sessao] -> [Sessao]
deleteSessaoPorIdentificador _ [] = []
deleteSessaoPorIdentificador identificador (sessao : outrasSessoes)
  | Modelos.Sessao.ident sessao == identificador = outrasSessoes
  | otherwise = sessao : deleteSessaoPorIdentificador identificador outrasSessoes

-- Verifica se uma sessao foi cadastrado a partir do id
contemSessao :: Int -> [Sessao] -> Bool
contemSessao _ [] = False
contemSessao idSessao (sessao:outrasSessoes)
    | Modelos.Sessao.ident sessao == idSessao = True
    | otherwise = contemSessao idSessao outrasSessoes


-- Funções que se comunicam com o Controller
-- Realiza as validações na sessao para adicionar ao JSON
adicionaSessao :: Sessao -> IO ()
adicionaSessao sessao = do
  if not (validaHorario (horario sessao))
    then do
      print "Horario invalido (hora >= 0 e <=23, minuto >=0 e <= 59)."
      threadDelay 1200000
    else do
      sessoesExistem <- getSessoesJSON
      if any (validaSessaoSala sessao) sessoesExistem
        then do
          putStrLn "Já existe uma sessão na mesma sala e horário."
          threadDelay 1200000
        else do
          adicionaSessaoJSON sessao
          putStrLn "Sessão cadastrada com sucesso!!"
          threadDelay 1200000

-- Pega uma sessão pelo seu id
getSessaoByID :: Int -> IO Sessao
getSessaoByID id = do
    sessao <- getSessoesJSON  -- Obter a lista de sessoes
    let filmeFake = Filme 0 "" "" ""
    let sessaoFake = Sessao 0 filmeFake ((0, 0)) 0 0
    let conteudo = fromMaybe sessaoFake (getSessaoAuxiliar id sessao)
    return conteudo

-- Função auxiliar para obter uma sessao da lista pelo ID
getSessaoAuxiliar :: Int -> [Sessao] -> Maybe Sessao
getSessaoAuxiliar _ [] = Nothing
getSessaoAuxiliar identifierS (x:xs)
    | Modelos.Sessao.ident x == identifierS = Just x
    | otherwise = getSessaoAuxiliar identifierS xs

getSessaoByNumeroDaInterface :: Int -> String -> IO Sessao
getSessaoByNumeroDaInterface numeroDaInterface tituloDofilme = do
    sessoes <- getSessoesJSON  -- Obter a lista de sessoes
    let filmeFake = Filme 0 "" "" ""
    let sessaoFake = Sessao 0 filmeFake ((0, 0)) 0 0
    let conteudo = fromMaybe sessaoFake (getSessaoAuxiliarByNumero numeroDaInterface tituloDofilme sessoes)
    return conteudo

-- Função auxiliar para obter uma sessao da lista pelo ID
getSessaoAuxiliarByNumero :: Int -> String -> [Sessao] -> Maybe Sessao
getSessaoAuxiliarByNumero _ _ [] = Nothing
getSessaoAuxiliarByNumero numeroDaInterface tituloDoFilme (x:xs) = do
  let filmeDaSessao = filme x 
  if (titulo filmeDaSessao) == tituloDoFilme then 
    if numeroDaInterface == 1 then Just x else getSessaoAuxiliarByNumero (numeroDaInterface -1) tituloDoFilme xs 
  else getSessaoAuxiliarByNumero numeroDaInterface tituloDoFilme xs

diminueCapacidadeSessao:: Int -> Int -> IO()
diminueCapacidadeSessao numIngressosComprados idSessao = do putStr ""

getIdPrimeiraSessao :: Compra -> Maybe Int
getIdPrimeiraSessao compra =
    case sessoesCompradas compra of
        [] -> Nothing 
        (sessao:_) -> Just $ Modelos.Sessao.ident sessao -- Retorna o ID da primeira sessao 

