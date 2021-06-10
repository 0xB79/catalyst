package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"golang.org/x/crypto/pbkdf2"
)

func post(url, authorization string, body map[string]string) ([]byte, error) {
	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	fmt.Println(string(b))

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(b))

	client := &http.Client{}
	req.Header.Add("Content-Type", `application/json`)
	if authorization != "" {
		req.Header.Add("Authorization", authorization)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 201 {
		return nil, fmt.Errorf("error: http response %s", resp.Status)
	}
	res, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return res, nil
}

type JWTResp struct {
	Token string `json:token`
}

type APITokenResp struct {
	ID string `json:id`
}

func main() {
	url := "http://127.0.0.1:80/api/user"
	fmt.Println("URL:>", url)

	salt, err := hex.DecodeString("69195A9476F08546")
	if err != nil {
		panic(err)
	}
	dk := pbkdf2.Key([]byte("password"), salt, 10000, 32, sha256.New)
	hash := strings.ToUpper(hex.EncodeToString(dk))
	var body = map[string]string{
		"email":    "admin@livepeer.dev",
		"password": hash,
	}
	_, err = post("http://127.0.0.1:80/api/user", "", body)
	if err != nil {
		panic(err)
	}
	jwtBytes, err := post("http://127.0.0.1:80/api/user/token", "", body)
	if err != nil {
		panic(err)
	}
	var jwt JWTResp
	err = json.Unmarshal(jwtBytes, &jwt)
	if err != nil {
		panic(err)
	}
	var apiTokenBody = map[string]string{
		"name": "System Token - DO NOT DELETE",
	}
	tokenBytes, err := post("http://127.0.0.1:80/api/api-token", fmt.Sprintf("JWT %s", jwt.Token), apiTokenBody)
	if err != nil {
		panic(err)
	}
	var token APITokenResp
	err = json.Unmarshal(tokenBytes, &token)
	if err != nil {
		panic(err)
	}
	fmt.Println(token.ID)
}