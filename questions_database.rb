require_relative 'model_base'
require 'sqlite3'
require 'singleton'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class User < ModelBase
  attr_accessor :fname, :lname, :options
  # def self.find_by_id(id)
  #   user = QuestionsDatabase.instance.execute(<<-SQL, id)
  #     SELECT
  #       *
  #     FROM
  #       users
  #     WHERE
  #       id = ?
  #   SQL
  #
  #   user.empty? ? nil : User.new(user.first)
  # end

  def self.find_by_name(fname,lname)
    user = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ?
        AND lname = ?
    SQL

    user.empty? ? nil : User.new(user.first)
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def self.get_database_name
    'users'
  end

  def save
    if @id.nil?
      #save it
      QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname)
        INSERT INTO
          users (fname, lname)
        VALUES
          (?, ?)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      #update it
      QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname, @id)
        UPDATE
          users
        SET
          fname = ?, lname = ?
        WHERE
          id = ?
      SQL
    end
  end



  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end
  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end
  def average_karma
    QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        count(question_likes.user_id) / CAST (( count ( DISTINCT questions.id)) AS FLOAT) AS karma
      FROM
        questions
      LEFT OUTER JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        questions.author_id = ?
    SQL

  end

end

class Question < ModelBase

  attr_accessor :title, :body, :author_id
  # def self.find_by_id(id)
  #   question = QuestionsDatabase.instance.execute(<<-SQL, id)
  #     SELECT
  #       *
  #     FROM
  #       questions
  #     WHERE
  #       id = ?
  #   SQL
  #
  #   question.empty? ? nil : Question.new(question.first)
  # end

  def self.find_by_author_id(author_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL

    questions.map {|question| Question.new(question)}
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end
  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end
  def self.get_database_name
    'questions'
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def save
    if @id.nil?
      #save
      QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @author_id)
        INSERT INTO
          questions (title, body, author_id)
        VALUES
          (?, ?, ?)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      #update
      QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @author_id, @id)
        UPDATE
          questions
        SET
          title = ?, body = ?, author_id = ?
        WHERE
          id = ?
      SQL

    end

  end
  def author
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_question_id(@id)
  end
  def followers
    QuestionFollow.followers_for_question_id(@id)
  end
  def likers
    QuestionLike.likers_for_question_id(@id)
  end
  def num_likes
    QuestionLike.num_likes_for_question_id(@id)
  end

end

class Reply < ModelBase

  attr_accessor :question_id, :parent_id, :user_id, :body
  # def self.find_by_id(id)
  #   reply = QuestionsDatabase.instance.execute(<<-SQL, id)
  #     SELECT
  #       *
  #     FROM
  #       replies
  #     WHERE
  #       id = ?
  #   SQL
  #
  #   reply.empty? ? nil : Reply.new(reply.first)
  # end

  def self.find_by_user_id(user_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL

    replies.map{|reply| Reply.new(reply)}
  end
  def self.find_by_question_id(question_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT *
      FROM replies
      WHERE question_id = ?
    SQL

  end

  def self.get_database_name
    "replies"
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @parent_id = options['parent_id']
    @user_id = options['user_id']
    @body = options['body']
  end

  def save
    if @id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, @question_id, @parent_id, @user_id, @body)
        INSERT INTO
          replies (question_id, parent_id, user_id, body)
        VALUES
          (?, ?, ?, ?)
      SQL
        @id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, @question_id, @parent_id, @user_id, @body, @id)
      UPDATE
       replies
      SET
        question_id = ?, parent_id = ?, user_id = ?, body = ?
      WHERE
        @id = ?
      SQL
    end
  end

  def author
    User.find_by_id(@user_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_id)
  end

  def child_replies
    replies = QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_id = ?
    SQL

    replies.map{ |reply| Reply.new(reply)}
  end

end

class QuestionFollow

  def self.followers_for_question_id(question_id)
    followers = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.*
      FROM users
      JOIN question_follows ON users.id = question_follows.follower_id
      WHERE question_follows.question_id = ?
    SQL

    followers.map {|follower| User.new(follower)}
  end

  def self.followed_questions_for_user_id(user_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT questions.*
      FROM questions
      JOIN question_follows ON questions.id = question_follows.question_id
      WHERE question_follows.follower_id = ?
    SQL

    questions.map {|question| Question.new(question)}

  end
#CANDRA needs to review this
  def self.most_followed_questions(n)
    questions = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      JOIN(
          SELECT
            question_id, count(question_id) AS count
          FROM
            question_follows
          GROUP BY
            question_id
          ORDER BY
            count(question_id) DESC
        ) AS popular_questions ON questions.id = popular_questions.question_id

      LIMIT
        ?
    SQL

    questions.map {|question| Question.new(question)}
  end
end

class QuestionLike
  def self.likers_for_question_id(question_id)
    users = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.*
      FROM
        users
      JOIN
        question_likes ON users.id = question_likes.user_id
      WHERE
        question_likes.question_id = ?
    SQL

    users.map{ |user| User.new(user)}
  end

  def self.num_likes_for_question_id(question_id)
    num_likes = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(user_id)
      FROM
        question_likes
      WHERE
        question_id = ?
    SQL
    num_likes.first
  end

  def self.liked_questions_for_user_id(user_id)
    liked_questions = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        question_likes.user_id = ?
    SQL

    liked_questions.map{ |question| Question.new(question)}
  end
  def self.most_liked_questions(n)
    most_liked = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      JOIN (
        SELECT
          questions_id, COUNT(user_id) as count
        FROM
          question_likes
        GROUP BY
          questions_id
        ORDER BY
          count DESC
      ) AS liked_questions ON liked_questions.questions_id = questions.id
      LIMIT ?
    SQL

    most_liked.map { |question| Question.new(question)}
  end
end



candra = User.find_by_id(2)
fena = User.find_by_id(1)
question_c = Question.find_by_author_id(2).first
question_f = Question.find_by_author_id(1).first
main_reply = Reply.find_by_id(1)
child_reply = Reply.find_by_id(3)
