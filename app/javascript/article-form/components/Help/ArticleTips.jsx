import { h } from 'preact';

export const ArticleTips = () => (
  <div
    data-testid="article-publishing-tips"
    className="crayons-article-form__help crayons-article-form__help--tags"
  >
    <h4 className="mb-2 fs-l">Поради з публікації</h4>
    <ul className="list-disc pl-6 color-base-70">
      <li>
Переконайтеся, що ваша публікація має обкладинку, щоб максимально ефективно використовувати домашню стрічку та соціальні мережі.
      </li>
      <li>
Поділіться своєю публікацією в соціальних мережах, з друзьями та мамою.
      </li>
      <li>

Попросіть людей залишати вам питання в коментарях. Це чудовий спосіб створити додаткову дискусію.
      </li>
    </ul>
  </div>
);
