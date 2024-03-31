module Servicos.Recomendacao.RecomendacaoServico where

import System.IO ( hFlush, stdout )
import Data.List (group, sort, maximumBy)
import Data.Function (on)
import Servicos.Cliente.ClienteController (retornaCliente)
import Modelos.Filme
import Modelos.Cliente
import Modelos.Cliente (Cliente(filmesAssistidos))
import Data.Bits (Bits(xor))
import Servicos.Matriz.MatrizServices
import System.Directory (renameFile, copyFile, removeFile)

import Servicos.Sessao.AtualizaSessaoInterfaceServico (loadSessoesDoFilme)
import Modelos.Sessao (Sessao(filme))
import Servicos.Filmes.FilmesController (getAllFilmesJSON)
import Data.String (String)
import Data.Char (toUpper)
import Menus.Compras.MenuCompraController (startMenuCompra)

constInterface:: String
constInterface = "./Interfaces/Recomendacoes/MenuRecomendacoesInterno.txt"

constInterfaceBase:: String
constInterfaceBase = "./Interfaces/Recomendacoes/MenuRecomendacoesInternoBase.txt"

constInterfaceTemp:: String
constInterfaceTemp = "./Interfaces/Recomendacoes/MenuRecomendacoesInternoTemp.txt"


recomendacaoCliente :: String -> IO()
recomendacaoCliente emailCliente = do
    cliente <- retornaCliente emailCliente
    let recomendacaoClienteGenero = analizaGenero (filmesAssistidos cliente)
    print recomendacaoClienteGenero
    let media = mediaHorarios (0,0) (filmesAssistidos cliente)
    --loadSessoesDoFilme 1
    print media
    filmes <- getAllFilmesJSON
    let filmesSelecionados = filmesRecomendadosGenero recomendacaoClienteGenero filmes 
    limparArquivo >> atualizaFilmesRecomendados 0 filmesSelecionados >> printMatrix "./Interfaces/Recomendacoes/MenuRecomendacoesInterno.txt"
    putStr "Digite I para comprar ingressos: "
    hFlush stdout
    escolha <- getLine
    if (paraMaiusculo escolha == "I")
        then
            startMenuCompra
        else
            recomendacaoCliente emailCliente

------- Funções internas do mudulo

-- Limpa o arquivo de interface 
limparArquivo:: IO()
limparArquivo = do
    copyFile constInterfaceBase constInterfaceTemp
    removeFile constInterface
    renameFile constInterfaceTemp constInterface

-- Modifica a interface de recomendacao, adicionando os filmes
atualizaFilmesRecomendados:: Int -> [Filme] -> IO()
atualizaFilmesRecomendados _ [] = return ()
atualizaFilmesRecomendados posicao (x:xs) = do
    writeMatrixValue "./Interfaces/Recomendacoes/MenuRecomendacoesInterno.txt" ("(" ++ (show (ident x)) ++")") (12+posicao) (4)
    writeMatrixValue "./Interfaces/Recomendacoes/MenuRecomendacoesInterno.txt" ( titulo x ) (12+posicao) (8)
    writeMatrixValue "./Interfaces/Recomendacoes/MenuRecomendacoesInterno.txt" ("Genero: " ++ genero x ) (13+posicao) (4)
    writeMatrixValue "./Interfaces/Recomendacoes/MenuRecomendacoesInterno.txt" ("Duracao: " ++ duracao x ) (14+posicao) (4)
    atualizaFilmesRecomendados (posicao+4) xs

-- Retorna qual genero tem a maior ocorrencia
analizaGenero:: [Filme] -> String
analizaGenero filmes =
    let generos = map genero filmes
        contagens = contarOcorrencias generos
        (generoMaisFrequente, _) = maximumBy (compare `on` snd) contagens
    in generoMaisFrequente

-- Função para contar ocorrências de cada elemento em uma lista
contarOcorrencias :: (Eq a, Ord a) => [a] -> [(a, Int)]
contarOcorrencias lista = map (\l@(x:_) -> (x, length l)) (group (sort lista))

-- Função que retorna a media de horarios dos filmes assistidos
mediaHorarios:: (Int, Int) -> [Filme] -> Int
mediaHorarios (x,y) [] = x `div` y
mediaHorarios (x,y) (head:tail) = mediaHorarios (x + (read (duracao head):: Int),y + 1) tail

-- Retorna os filmes disponiveis que tem o msm gênero que o gênero preferido do cliente
filmesRecomendadosGenero:: String -> [Filme] -> [Filme]
filmesRecomendadosGenero _ [] = []
filmesRecomendadosGenero generoFilme (x:xs)
    |removeEspacosEMaiusculo generoFilme == removeEspacosEMaiusculo (genero x) = x : filmesRecomendadosGenero generoFilme xs
    |otherwise = filmesRecomendadosGenero generoFilme xs

-- Função para remover espaços em branco
removeEspacos :: String -> String
removeEspacos = filter (/= ' ')

-- Função para converter para maiúsculas
paraMaiusculo :: String -> String
paraMaiusculo = map toUpper

-- Função que remove espaços em branco e converte para maiúsculas
removeEspacosEMaiusculo :: String -> String
removeEspacosEMaiusculo = paraMaiusculo . removeEspacos

