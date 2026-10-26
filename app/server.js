import express from 'express';


const app = express();
app.use(express.json());

// Read config

const PORT = process.env.PORT || 3000;

// Temporary in-memory 
const items = [
    {id: 1, name: "Keyboard", price: 500 },
    {id: 2, name: "Mouse", price: 200 },
    {id: 3, name: "printer", price: 690 },
    {id: 4, name: "NoteBook", price: 399 }
]


app.get("/health", (req, res) => {
    res.json({ status: "ok" });
});

app.get("/api/items", (req, res) => {
    res.json(items);
});

app.post("api/items", (req, res) => {
    const item = { id: items.length + 1, name: req.body.name, price: req.body.price };
    items.push(item);
    res.status(201).json(item)
})



app.listen(PORT, () => {
    console.log(`server run on port ${PORT}`)
})