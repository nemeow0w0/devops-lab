import express from 'express';
import pg from 'pg';



const app = express();
app.use(express.json());

// Read config
const pool = new pg.Pool();
const PORT = process.env.PORT || 3355;



app.get("/health", async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({ status: "ok" });

    } catch {
        res.status(503).json({ status: "up down"})
    }
});

app.get("/api/items", async(req, res) => {
    const { rows } = await pool.query('SELECT id, name, price FROM items ORDER BY id ASC');
    res.json(rows);
});

app.post("/api/items", async (req, res) => {

    const { rows } = await pool.query('INSERT INTO items (name, price) VALUES ($1, $2) RETURNING *', [req.body.name, req.body.price]);
    res.status(201).json(rows[0])
})

await pool.query('CREATE TABLE IF NOT EXISTS items (id serial PRIMARY KEY, name text NOT NULL, price int NOT NULL)');


app.listen(PORT, () => {
    console.log(`server run on port ${PORT}`)
})