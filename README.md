# rearrangeRepositories
Este es un script en bash que se ha realizado para poder reorganizar todos los repositorios de GitHub que compartan una parte del nombre en un solo repositorio. El objetivo principal era reorganizar todos los laboratorios realizados durante el bootcamp de IronHack (todos comienzan por "lab") en un solo repositorio estructurado en carpetas.
***

## ¿Cómo ejecutar la herramienta?

Para ejecutar el script los comandos que hay que correr en la terminal son:
```
git clone https://github.com/rodrigogalan/rearrangeRepos
cd rearrangeRepos
chmod +x rearrangeRepos.sh
```
Posteriormente hay que crear el archivo de credenciales en formato .json que contenga el nombre de usuario y un [token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) de la cuenta personal de github donde se quieran hacer los cambios. Debe tener la estructura:
```
{
    "username": "jonhDoe",
    "token": "github_pat_xxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```


Con esto ya tendriamos el script en local con permisos de ejecución y el archivo de credenciales. A la hora de ejecutar el script hay varios parámetros:
- Parámetro -h: despliega el menú de ayuda
- Parámetro -s string: permite modificar el string que comparten todos los repositorios, por defecto tiene el valor "lab"
- Parámetro -f filename: permite modificar la ruta del archivo de credenciales, por defecto vale "./config.json". Puede ponerse la ruta relativa o absoluta.
- Parámetro -n number_of_folders: permite modificar el número de carpetas que se van a crear en la estrucutura. El número por defecto es 7.
- Parámetro -c name_of_folders: permite modificar el nombre de las carpetas que se van a crear en la estrucutura. El nombre por defecto es "week".

Por ejemplo para ejecutar la herramienta y hacerla actuar sobre los repositorios que contengan el string "python" en el nombre y el archivo de credenciales esté en la ruta "~/credentials.json", con 10 carpetas en la estructura y con nombre "custom_name" el comando es:
```
./rearrangeRepos -s python -f ~/credentials.json -n 10 -c "custom_name"
```
