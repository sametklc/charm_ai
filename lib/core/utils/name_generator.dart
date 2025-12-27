/// Utility to generate culturally appropriate names based on nationality and gender
class NameGenerator {
  NameGenerator._();

  /// Get appropriate names for a nationality and gender
  static String getRandomName(String nationality, String gender) {
    final isMale = gender.toLowerCase() == 'male';
    final names = getNamePool(nationality, isMale);
    
    if (names.isEmpty) {
      // Fallback to generic names if nationality not found
      return isMale 
          ? _genericMaleNames[DateTime.now().millisecondsSinceEpoch % _genericMaleNames.length]
          : _genericFemaleNames[DateTime.now().millisecondsSinceEpoch % _genericFemaleNames.length];
    }
    
    return names[DateTime.now().millisecondsSinceEpoch % names.length];
  }

  /// Get name pool for nationality and gender (public for access in discover screen)
  static List<String> getNamePool(String nationality, bool isMale) {
    return _getNamePool(nationality, isMale);
  }

  static List<String> _getNamePool(String nationality, bool isMale) {
    final normalizedNationality = nationality.toLowerCase().trim();
    
    switch (normalizedNationality) {
      // Turkish
      case 'turkish':
        return isMale 
            ? ['Emre', 'Can', 'Burak', 'Kerem', 'Arda', 'Alp', 'Deniz', 'Efe', 'Cem', 'Ozan', 'Kaan', 'Barış', 'Tolga', 'Berk', 'Yiğit']
            : ['Ayşe', 'Elif', 'Zeynep', 'Merve', 'Selin', 'Dilara', 'Ceren', 'Burcu', 'Sude', 'İrem', 'Defne', 'Melis', 'Ece', 'Asya', 'Ada'];
      
      // American
      case 'american':
        return isMale
            ? ['James', 'Michael', 'David', 'William', 'Robert', 'Daniel', 'Matthew', 'Christopher', 'Andrew', 'Joseph', 'Ryan', 'Justin', 'Brandon', 'Tyler']
            : ['Emily', 'Sarah', 'Jessica', 'Amanda', 'Jennifer', 'Melissa', 'Nicole', 'Michelle', 'Ashley', 'Stephanie', 'Lauren', 'Rachel', 'Elizabeth', 'Megan'];
      
      // British
      case 'british':
        return isMale
            ? ['Oliver', 'Jack', 'Harry', 'George', 'Charlie', 'Thomas', 'William', 'James', 'Henry', 'Freddie', 'Arthur', 'Noah', 'Oscar', 'Theo']
            : ['Olivia', 'Sophia', 'Amelia', 'Isabella', 'Mia', 'Grace', 'Poppy', 'Emily', 'Ella', 'Freya', 'Lily', 'Ava', 'Charlotte', 'Harper'];
      
      // French
      case 'french':
        return isMale
            ? ['Lucas', 'Hugo', 'Louis', 'Gabriel', 'Raphaël', 'Nathan', 'Léo', 'Adam', 'Arthur', 'Noah', 'Jules', 'Mael', 'Liam', 'Paul']
            : ['Emma', 'Léa', 'Chloé', 'Manon', 'Inès', 'Camille', 'Sarah', 'Louise', 'Lola', 'Jade', 'Zoé', 'Marie', 'Juliette', 'Anna'];
      
      // Italian
      case 'italian':
        return isMale
            ? ['Francesco', 'Alessandro', 'Lorenzo', 'Leonardo', 'Mattia', 'Andrea', 'Gabriele', 'Tommaso', 'Riccardo', 'Edoardo', 'Giuseppe', 'Antonio', 'Marco', 'Davide']
            : ['Sofia', 'Giulia', 'Aurora', 'Alice', 'Ginevra', 'Emma', 'Giorgia', 'Greta', 'Beatrice', 'Anna', 'Francesca', 'Vittoria', 'Chiara', 'Matilde'];
      
      // Spanish
      case 'spanish':
        return isMale
            ? ['Hugo', 'Martín', 'Lucas', 'Mateo', 'Leo', 'Daniel', 'Alejandro', 'Pablo', 'Manuel', 'Álvaro', 'Adrián', 'Mario', 'Enzo', 'Diego']
            : ['Lucía', 'Sofía', 'Martina', 'María', 'Paula', 'Julia', 'Emma', 'Daniela', 'Carla', 'Alba', 'Noa', 'Olivia', 'Carmen', 'Chloe'];
      
      // German
      case 'german':
        return isMale
            ? ['Ben', 'Jonas', 'Finn', 'Paul', 'Luis', 'Henry', 'Noah', 'Emil', 'Matteo', 'Theo', 'Felix', 'Leon', 'Maximilian', 'Anton']
            : ['Emma', 'Hannah', 'Mia', 'Emilia', 'Sofia', 'Lina', 'Ella', 'Lea', 'Anna', 'Marie', 'Mila', 'Luisa', 'Clara', 'Frieda'];
      
      // Japanese
      case 'japanese':
        return isMale
            ? ['Hiroshi', 'Kenji', 'Takashi', 'Yuki', 'Satoshi', 'Ryota', 'Daiki', 'Yuto', 'Haruki', 'Ren', 'Sora', 'Kaito', 'Riku', 'Hayato']
            : ['Sakura', 'Yuki', 'Hana', 'Akari', 'Mei', 'Rin', 'Mio', 'Aoi', 'Yui', 'Koharu', 'Haruka', 'Nanami', 'Rika', 'Ayaka'];
      
      // Korean
      case 'korean':
        return isMale
            ? ['Min-jun', 'Seo-jun', 'Do-yun', 'Si-woo', 'Jun-seo', 'Eun-woo', 'Woo-jin', 'Ji-hoon', 'Hyun-woo', 'Dae-hyun', 'Jin-woo', 'Sung-min', 'Min-ho', 'Jae-hyun']
            : ['Ji-woo', 'Seo-yeon', 'Yoo-jin', 'Ha-eun', 'Seo-yun', 'Chae-won', 'Min-seo', 'Soo-ah', 'Ye-seul', 'Na-yeon', 'Ha-rin', 'Ji-min', 'Eun-ji', 'Su-bin'];
      
      // Brazilian
      case 'brazilian':
        return isMale
            ? ['Gabriel', 'Matheus', 'Lucas', 'Pedro', 'Rafael', 'Felipe', 'Thiago', 'Gustavo', 'Bruno', 'João', 'Vitor', 'Caio', 'Guilherme', 'Leonardo']
            : ['Maria', 'Ana', 'Juliana', 'Fernanda', 'Patricia', 'Beatriz', 'Carolina', 'Amanda', 'Camila', 'Gabriela', 'Isabella', 'Larissa', 'Mariana', 'Vanessa'];
      
      // Australian
      case 'australian':
        return isMale
            ? ['Oliver', 'Jack', 'William', 'Noah', 'James', 'Lucas', 'Mason', 'Ethan', 'Alexander', 'Henry', 'Charlie', 'Liam', 'Oscar', 'Logan']
            : ['Charlotte', 'Olivia', 'Amelia', 'Isla', 'Mia', 'Ava', 'Grace', 'Sophia', 'Ella', 'Chloe', 'Ruby', 'Lily', 'Emma', 'Harper'];
      
      // Canadian
      case 'canadian':
        return isMale
            ? ['Liam', 'Noah', 'Lucas', 'Oliver', 'Benjamin', 'William', 'James', 'Mason', 'Ethan', 'Alexander', 'Henry', 'Michael', 'Daniel', 'Logan']
            : ['Olivia', 'Emma', 'Charlotte', 'Sophia', 'Amelia', 'Isabella', 'Mia', 'Ava', 'Ella', 'Harper', 'Grace', 'Chloe', 'Lily', 'Emily'];
      
      // Mexican
      case 'mexican':
        return isMale
            ? ['Santiago', 'Mateo', 'Sebastián', 'Diego', 'Nicolás', 'Samuel', 'Jesús', 'Daniel', 'Lucas', 'Emiliano', 'Ángel', 'Carlos', 'Miguel', 'Alejandro']
            : ['Sofía', 'Valentina', 'Regina', 'Ximena', 'Camila', 'Mariana', 'Andrea', 'Gabriela', 'Isabella', 'Victoria', 'Daniela', 'Natalia', 'Fernanda', 'Jimena'];
      
      // Russian
      case 'russian':
        return isMale
            ? ['Aleksandr', 'Dmitri', 'Ivan', 'Mikhail', 'Sergey', 'Andrey', 'Aleksey', 'Vladimir', 'Nikolay', 'Maxim', 'Roman', 'Pavel', 'Denis', 'Viktor']
            : ['Anna', 'Maria', 'Elena', 'Olga', 'Tatyana', 'Natalia', 'Irina', 'Svetlana', 'Ekaterina', 'Yulia', 'Anastasia', 'Daria', 'Ksenia', 'Victoria'];
      
      // Indian
      case 'indian':
        return isMale
            ? ['Arjun', 'Rohan', 'Vikram', 'Raj', 'Aryan', 'Krishna', 'Dev', 'Aarav', 'Vihaan', 'Aditya', 'Rahul', 'Ravi', 'Siddharth', 'Ankit']
            : ['Priya', 'Ananya', 'Kavya', 'Aaradhya', 'Diya', 'Isha', 'Meera', 'Radha', 'Saanvi', 'Anika', 'Pooja', 'Neha', 'Shreya', 'Tara'];
      
      // Chinese
      case 'chinese':
        return isMale
            ? ['Wei', 'Ming', 'Jun', 'Tao', 'Lei', 'Jian', 'Hao', 'Kai', 'Chen', 'Li', 'Wang', 'Zhang', 'Liu', 'Yang']
            : ['Mei', 'Lin', 'Fang', 'Xia', 'Yan', 'Li', 'Hui', 'Jing', 'Ling', 'Qing', 'Wen', 'Xin', 'Yuan', 'Zhen'];
      
      // Swedish
      case 'swedish':
        return isMale
            ? ['William', 'Liam', 'Lucas', 'Noah', 'Elias', 'Hugo', 'Oliver', 'Alexander', 'Adam', 'Viktor', 'Leo', 'Emil', 'Axel', 'Oscar']
            : ['Alice', 'Ella', 'Maja', 'Lily', 'Ebba', 'Olivia', 'Astrid', 'Saga', 'Freja', 'Wilma', 'Alma', 'Nora', 'Elsa', 'Sara'];
      
      // Norwegian
      case 'norwegian':
        return isMale
            ? ['Noah', 'Lucas', 'Oliver', 'William', 'Emil', 'Henrik', 'Jakob', 'Liam', 'Oskar', 'Filip', 'Elias', 'Alexander', 'Sander', 'Magnus']
            : ['Nora', 'Emma', 'Olivia', 'Sofia', 'Ella', 'Maja', 'Ingrid', 'Emilie', 'Sophia', 'Leah', 'Sara', 'Thea', 'Aurora', 'Linnea'];
      
      default:
        return isMale ? _genericMaleNames : _genericFemaleNames;
    }
  }

  // Generic fallback names
  static const List<String> _genericMaleNames = [
    'Alex', 'Jordan', 'Sam', 'Chris', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Jamie', 'Avery'
  ];
  
  static const List<String> _genericFemaleNames = [
    'Alex', 'Jordan', 'Sam', 'Chris', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Jamie', 'Avery'
  ];
}

