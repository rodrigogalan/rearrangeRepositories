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
Posteriormente hay que crear dos variables de entorno para almacenar las credenciales de la cuenta: el nombre de usuario y el [token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) de la cuenta personal de github donde se quieran hacer los cambios. Los comandos necesarios son:
```
export GITHUB_USERNAME="jonh_doe"
export GITHUB_TOKEN="github_pat_xxxxxxxxxxxxxxxxxxxxxxxxxxx"
```


Con esto ya tendriamos el script en local con permisos de ejecución y las variables con las credenciales requeridas. A la hora de ejecutar el script hay varios parámetros:
- Parámetro -h: despliega el menú de ayuda
- Parámetro -s string: permite modificar el string que comparten todos los repositorios, por defecto tiene el valor "lab"
- Parámetro -n number_of_folders: permite modificar el número de carpetas que se van a crear en la estrucutura. El número por defecto es 7.
- Parámetro -c name_of_folders: permite modificar el nombre de las carpetas que se van a crear en la estrucutura (no puede contener espacios). El nombre por defecto es "week".

Por ejemplo para ejecutar la herramienta y hacerla actuar sobre los repositorios que contengan el string "python" en el nombre, con 10 carpetas en la estructura y con nombre "custom_name" el comando es:
```
./rearrangeRepos -s python -n 10 -c "custom_name"
```
