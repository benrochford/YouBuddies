import express, { Express, Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import { collectRecsUser } from "../../functions/src/collector";

dotenv.config();

const app: Express = express();
const port = process.env.PORT || 3000;
app.use(express.json());

const corsOptions = {
  origin: ['http://localhost:1269', 'https://youbuddy-96438.web.app', 'https://youbuddy-96438.firebaseapp.com']
};
app.use(cors(corsOptions));

app.post("/collect", (req: Request, res: Response) => {
  try {
    console.log(req.body);
  } catch(error) {
    res.status(500).json(error);
  }

  if ('userId' in req.body) {
    const userId = req.body.userId;
    collectRecsUser(userId)
      .then(() => res.sendStatus(200))
      .catch(error => res.status(500).json(error));
  }
});

app.listen(port, () => {
  console.log(`[server]: Server is running on port ${port}`);
});
